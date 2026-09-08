class SourcesController < ApplicationController
  before_action :set_source, only: %i[show edit update destroy test]

  def index
    @sources = Source.order(:name).includes(:providable)
  end

  def show
  end

  def new
    @type = permitted_type(params[:type])

    if @type.nil?
      render :choose_type
    else
      provider = Source.provider_class(@type)
      @source  = Source.new(
        providable: provider.new(provider.defaults),
        refresh_seconds: provider.default_refresh_seconds
      )
    end
  end

  def create
    @type = permitted_type(params[:type] || params.dig(:source, :providable_type))
    return redirect_to(new_source_path, alert: "Unknown source type") if @type.nil?

    @source = Source.new(source_params)
    @source.providable = Source.provider_class(@type).new(provider_params(@type))

    if save_with_provider(@source)
      redirect_to sources_path, notice: "#{@source.name} added"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    type = @source.providable_type

    Source.transaction do
      @source.providable.update!(provider_params(type))
      @source.update!(source_params)
    end

    redirect_to sources_path, notice: "#{@source.name} updated"
  rescue ActiveRecord::RecordInvalid
    merge_provider_errors(@source)
    render :edit, status: :unprocessable_content
  end

  def destroy
    if @source.in_use?
      names = @source.dashboard_items.map { |i| i.title.presence || i.kind }
      return redirect_to sources_path,
                         alert: "Still used by: #{names.to_sentence}"
    end

    @source.destroy
    redirect_to sources_path, notice: "Deleted"
  end

  # Runs fetch! immediately and reports what came back.
  #
  # NotImplementedError is rescued by name because it descends from
  # ScriptError, not StandardError -- IcalProvider has no fetch! until
  # Phase 6, and an unrescued raise here would be a 500.
  def test
    payload = @source.providable.fetch!
    @source.record_success(payload)

    redirect_to sources_path,
                notice: "#{@source.name}: #{summarize(payload)}"
  rescue NotImplementedError
    redirect_to sources_path,
                alert: "#{@source.name}: #{@source.kind_label} fetching is not built yet"
  rescue StandardError => e
    @source.record_failure(e)
    redirect_to sources_path, alert: "#{@source.name}: #{e.message}"
  end

  # Place-name lookup for weather sources.
  def geocode
    render json: { results: Geocoding.search(params[:q]) }
  rescue Http::Error => e
    render json: { results: [], error: e.message }, status: :bad_gateway
  end

  private

    def set_source
      @source = Source.find(params.expect(:id))
    end

    def permitted_type(type)
      Source::PROVIDERS.find { |known| known == type.to_s }
    end

    # delegated_type's providable_id is NOT NULL, so an invalid provider
    # makes Source#save raise a NotNullViolation instead of returning
    # false. Save the provider first, then surface its errors on the
    # source so the form has something to render.
    def save_with_provider(source)
      saved = false

      Source.transaction do
        saved = source.providable.save && source.save
        raise ActiveRecord::Rollback unless saved
      end

      merge_provider_errors(source) unless saved
      saved
    end

    def merge_provider_errors(source)
      source.providable.errors.each do |error|
        source.errors.add(:base, error.full_message)
      end
    end

    def source_params
      params.expect(source: [ :name, :refresh_seconds ])
    end

    def provider_params(type)
      klass   = Source.provider_class(type)
      allowed = Array(klass&.form_attributes) + Array(klass&.extra_params)
      params.require(:source)
            .fetch(:provider, ActionController::Parameters.new)
            .permit(*allowed)
    end

    def summarize(payload)
      if payload["items"]
        "#{payload['items'].size} items, newest: " \
          "#{payload['items'].first&.dig('title')&.truncate(60)}"
      elsif payload.dig("current", "temp")
        "#{payload.dig('current', 'temp')}° #{payload.dig('current', 'label')}"
      elsif payload["events"]
        "#{payload['events'].size} events"
      else
        "fetched OK"
      end
    end
end
