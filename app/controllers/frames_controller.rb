class FramesController < ApplicationController
  skip_forgery_protection

  before_action :set_device
  before_action :advance_dashboard
  before_action :record_telemetry

  def show
    response.set_header("Refresh-Rate", @device.sleep_seconds.to_s)
    response.set_header("Dashboard-Name", @device.dashboard&.name.to_s)

    frame = current_frame
    return head(:service_unavailable) if frame.nil?

    # A forced render always ships bytes — the button press means the
    # person is standing there waiting for the screen to change.
    if forced?
      send_frame(frame)
    elsif stale?(etag: frame.checksum,
                 last_modified: frame.rendered_at, public: false)
      send_frame(frame)
    end
  end

  private

  def set_device
    @device = Device.find_by!(token: params[:token])
  end

  # Rotating before render means one request covers both the switch and
  # the new image.
  def advance_dashboard
    return unless request.headers["X-Dashboard-Advance"].present?

    @device.advance_dashboard!
    @device.reload
  end

  def record_telemetry
    @device.update_columns({
      last_seen_at: Time.current,
      battery_percent: header_int("X-Battery-Percent"),
      battery_voltage: header_float("X-Battery-Voltage"),
      wifi_rssi: header_int("X-Wifi-RSSI"),
      firmware_version: request.headers["X-Firmware-Version"].presence
    }.compact)
  end

  def forced?
    request.headers["X-Refresh"].to_s == "force" ||
      request.headers["X-Dashboard-Advance"].present?
  end

  def current_frame
    frame = @device.current_frame

    if forced? || frame.nil? || pending?(frame)
      frame = FrameComposer.call(@device)
      @device.update_columns(refresh_requested_at: nil)
    end

    frame
  rescue StandardError => e
    Rails.logger.error("[Frames] render failed: #{e.class}: #{e.message}")
    @device.current_frame
  end

  def pending?(frame)
    @device.refresh_requested_at.present? &&
      @device.refresh_requested_at > frame.rendered_at
  end

  def send_frame(frame)
    send_data frame.data,
              type: frame.format == "raw" ? "application/octet-stream" : "image/bmp",
              disposition: "inline"
  end

  def header_int(name)
    value = request.headers[name]
    value.presence && value.to_i
  end

  def header_float(name)
    value = request.headers[name]
    value.presence && value.to_f
  end
end
