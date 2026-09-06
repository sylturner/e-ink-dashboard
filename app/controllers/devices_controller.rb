class DevicesController < ApplicationController
  before_action :set_device, only: %i[ show edit update destroy ]

  # GET /devices or /devices.json
  def index
    @devices = Device.all
  end

  # GET /devices/1 or /devices/1.json
  def show
  end

  # GET /devices/new
  def new
    @device = Device.new
  end

  # GET /devices/1/edit
  def edit
  end

  # POST /devices or /devices.json
  def create
    @device = Device.new(device_params)

    respond_to do |format|
      if @device.save
        format.html { redirect_to @device, notice: "Device was successfully created." }
        format.json { render :show, status: :created, location: @device }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @device.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /devices/1 or /devices/1.json
  def update
    respond_to do |format|
      if @device.update(device_params)
        format.html { redirect_to @device, notice: "Device was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @device }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @device.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /devices/1 or /devices/1.json
  def destroy
    @device.destroy!

    respond_to do |format|
      format.html { redirect_to devices_path, notice: "Device was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_device
      @device = Device.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def device_params
      params.expect(device: [ :name, :dashboard_id, :width, :height, :bit_depth, :image_format, :rotation, :refresh_seconds, :night_refresh_seconds, :active_from_hour, :active_until_hour, :time_zone, :last_seen_at, :battery_percent, :battery_voltage, :wifi_rssi, :firmware_version, :refresh_requested_at ])
    end
end
