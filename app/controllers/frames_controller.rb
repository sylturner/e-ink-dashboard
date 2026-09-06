class FramesController < ApplicationController
  skip_forgery_protection

  before_action :set_device
  before_action :record_telemetry

  def show
    response.set_header("Refresh-Rate", @device.sleep_seconds.to_s)

    frame = current_frame
    return head(:service_unavailable) if frame.nil?

    return unless stale?(etag: frame.checksum,
                         last_modified: frame.rendered_at,
                         public: false)

    send_data frame.data,
              type: content_type(frame),
              disposition: "inline"
  end

  private

  def set_device
    @device = Device.find_by!(token: params[:token])
  end

  def record_telemetry
    attrs = { last_seen_at: Time.current }

    attrs[:battery_percent]  = header_int("X-Battery-Percent")
    attrs[:battery_voltage]  = header_float("X-Battery-Voltage")
    attrs[:wifi_rssi]        = header_int("X-Wifi-RSSI")
    attrs[:firmware_version] = request.headers["X-Firmware-Version"].presence

    @device.update_columns(attrs.compact)
  end

  def current_frame
    frame = @device.current_frame

    if frame.nil? || refresh_pending?(frame)
      frame = FrameComposer.call(@device)
      @device.update_columns(refresh_requested_at: nil)
    end

    frame
  rescue StandardError => e
    Rails.logger.error("[Frames] render failed: #{e.class}: #{e.message}")
    @device.current_frame
  end

  def refresh_pending?(frame)
    @device.refresh_requested_at.present? &&
      @device.refresh_requested_at > frame.rendered_at
  end

  def content_type(frame)
    frame.format == "raw" ? "application/octet-stream" : "image/bmp"
  end

  def header_int(name)
    v = request.headers[name]
    v.presence && v.to_i
  end

  def header_float(name)
    v = request.headers[name]
    v.presence && v.to_f
  end
end
