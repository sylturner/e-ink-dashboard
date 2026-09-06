class DashboardItemsController < ApplicationController
  before_action :set_dashboard_item, only: %i[ show edit update destroy reposition ]

  # GET /dashboard_items or /dashboard_items.json
  def index
    @dashboard_items = DashboardItem.all
  end

  # GET /dashboard_items/1 or /dashboard_items/1.json
  def show
  end

  # GET /dashboard_items/new
  def new
    @dashboard_item = DashboardItem.new
  end

  # GET /dashboard_items/1/edit(?kind=weather)
  #
  # The inspector re-requests itself with ?kind= when the component is
  # changed, so the form can be rebuilt with that kind's layouts,
  # sources and settings before anything is saved.
  def edit
    return if params[:kind].blank? || !Component::KINDS.include?(params[:kind])

    @dashboard_item.kind = params[:kind]
    @dashboard_item.view = Component.default_view(@dashboard_item.kind)
    @dashboard_item.settings = {}
  end

  # POST /dashboard_items or /dashboard_items.json
  def create
    @dashboard = Dashboard.find(params.dig(:dashboard_item, :dashboard_id))
    @dashboard_item = @dashboard.dashboard_items.new(dashboard_item_params)

    slot = FreeSlot.find(@dashboard, @dashboard_item.col_span, @dashboard_item.row_span)

    if slot.nil?
      return redirect_to builder_dashboard_path(@dashboard),
                         alert: "No room on the grid for that size."
    end

    @dashboard_item.col, @dashboard_item.row = slot
    @dashboard_item.position = @dashboard.dashboard_items.maximum(:position).to_i + 1

    if @dashboard_item.save
      redirect_to builder_dashboard_path(@dashboard),
                  notice: "Added #{@dashboard_item.kind}."
    else
      redirect_to builder_dashboard_path(@dashboard),
                  alert: @dashboard_item.errors.full_messages.to_sentence
    end
  end

  # PATCH/PUT /dashboard_items/1 or /dashboard_items/1.json
  def update
    respond_to do |format|
      if @dashboard_item.update(dashboard_item_params)
        format.html { redirect_to builder_dashboard_path(@dashboard_item.dashboard), notice: "Dashboard item was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @dashboard_item }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @dashboard_item.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH /dashboard_items/1/reposition
  #
  # The builder's drag/resize endpoint. JSON only, and deliberately
  # narrow: it moves and resizes, nothing else. `fits_within_grid` on the
  # model stays the authority, so a rejected move rolls back client-side.
  def reposition
    if @dashboard_item.update(reposition_params)
      render json: { ok: true }
    else
      render json: { ok: false, errors: @dashboard_item.errors.full_messages },
             status: :unprocessable_content
    end
  end

  # DELETE /dashboard_items/1 or /dashboard_items/1.json
  def destroy
    dashboard = @dashboard_item.dashboard
    @dashboard_item.destroy!

    respond_to do |format|
      format.html { redirect_to builder_dashboard_path(dashboard), notice: "Dashboard item was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dashboard_item
      @dashboard_item = DashboardItem.find(params.expect(:id))
    end

    def reposition_params
      params.expect(dashboard_item: [ :col, :row, :col_span, :row_span ])
    end

    # Only allow a list of trusted parameters through. Position and
    # placement are owned by the builder, not by these forms.
    #
    # settings is an arbitrary hash: the keys are whatever the registry
    # rendered and the values only ever reach ERB. Do not extend that to
    # anything that reaches SQL or send.
    def dashboard_item_params
      params.expect(dashboard_item: [ :dashboard_id, :kind, :view, :title,
                                      :col_span, :row_span, :visible,
                                      { source_ids: [], settings: {} } ])
    end
end
