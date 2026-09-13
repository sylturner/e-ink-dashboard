class DevicesController < ApplicationController
  before_action :set_device, only: %i[ edit update destroy refresh ]

  # GET /devices
  #
  # Panels waiting to be claimed, then a card for each one showing a
  # dashboard.
  def index
    @pending    = Device.where(dashboard_id: nil).order(:enrolled_at, :name)
    @devices    = Device.where.not(dashboard_id: nil).includes(:dashboard).order(:name)
    @dashboards = Dashboard.order(:name)
    # Which cards have a frame to show, without loading the bitmaps.
    @framed_ids = Frame.rendered.where(device_id: @devices.map(&:id)).distinct.pluck(:device_id).to_set
  end

  # GET /devices/new
  #
  # Panels normally add themselves (EnrollmentsController); this is for
  # adding one by hand.
  def new
    @device = Device.new
  end

  # GET /devices/1/edit
  #
  # The device's page: its last frame and check-ins, its dashboards and
  # its settings.
  def edit
    load_device_page
  end

  # POST /devices
  def create
    @device = Device.new(device_params)

    if @device.save
      redirect_to edit_device_path(@device), notice: "#{@device.name} was created. Assign it a dashboard."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /devices/1
  #
  # The settings form, and the dashboard card's "Switch to" buttons.
  def update
    if @device.update(device_params)
      # A frame is only composed when one is due, so without this a new
      # dashboard or dither would wait for the next scheduled render.
      @device.request_refresh! if @device.frame_settings_changed?

      redirect_to edit_device_path(@device), notice: update_notice, status: :see_other
    else
      load_device_page
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /devices/1
  def destroy
    @device.destroy!

    redirect_to devices_path, notice: "#{@device.name} was deleted.", status: :see_other
  end

  # POST /devices/1/refresh
  def refresh
    @device.request_refresh!

    redirect_back_or_to edit_device_path(@device),
                        notice: "#{@device.name} will get a fresh frame when it next wakes.",
                        status: :see_other
  end

  private
    def set_device
      @device = Device.find(params.expect(:id))
    end

    # A rejected save re-renders the page with the form's values, so the
    # status and dashboards cards read a fresh copy of what is saved.
    def load_device_page
      @saved_device = @device.changed? ? Device.find(@device.id) : @device
      @assignments  = @saved_device.device_dashboards.includes(:dashboard)
      @assignable_dashboards = Dashboard.where.not(id: @assignments.map(&:dashboard_id)).order(:name)
      @frame_rendered_at = @saved_device.frames.rendered.maximum(:rendered_at)
    end

    def update_notice
      if @device.saved_change_to_dashboard_id? && @device.dashboard
        "#{@device.name} will show #{@device.dashboard.name} when it next wakes."
      else
        "#{@device.name} was saved."
      end
    end

    # Telemetry and assignments are left out: the panel reports the one,
    # and DeviceDashboardsController changes the other.
    def device_params
      params.expect(device: [ :name, :dashboard_id, :width, :height, :bit_depth, :image_format, :dither, :rotation,
                              :refresh_seconds, :night_refresh_seconds, :active_from_hour, :active_until_hour, :time_zone ])
    end
end
