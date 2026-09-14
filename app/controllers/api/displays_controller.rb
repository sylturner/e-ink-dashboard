# GET /api/display
#
# A panel's check-in: it reports how it is doing and is told which image
# to show and when to come back. The answer is always a 200; the JSON
# status is what the firmware acts on.
class Api::DisplaysController < Api::BaseController
  # What the firmware keeps for its special-function button (a double
  # click on a TRMNL, a long press on the esp32/ sketch). Pressing it
  # sends a special_function header, and the panel moves to its next
  # dashboard.
  SPECIAL_FUNCTION = "restart_playlist"

  def show
    # On a 500 the firmware drops its API key and sets itself up again,
    # which is what a panel deleted here needs.
    return render(json: { status: 500 }) if current_device.nil?

    record_telemetry

    if special_function?
      current_device.advance_dashboard!
      current_device.reload
    end

    frame = current_frame
    refresh_rate = current_device.sleep_seconds

    # Nothing to show yet: the panel comes back soon without redrawing.
    return render(json: { status: 202, refresh_rate: refresh_rate }) if frame.nil?

    render json: {
      status: 0,
      image_url: api_image_url(frame, format: frame.format),
      filename: frame.filename,
      refresh_rate: refresh_rate,
      reset_firmware: false,
      update_firmware: false,
      firmware_url: nil,
      special_function: SPECIAL_FUNCTION,
      action: (SPECIAL_FUNCTION if special_function?)
    }
  end

  private

    def record_telemetry
      voltage = header_float("Battery-Voltage")

      current_device.update_columns({
        last_seen_at: Time.current,
        battery_voltage: voltage,
        battery_percent: header_int("Percent-Charged") || Device.battery_percent_for(voltage),
        wifi_rssi: header_int("RSSI"),
        firmware_version: request.headers["FW-Version"].presence
      }.compact)
    end

    # The firmware's special_function header reaches the app as
    # HTTP_SPECIAL_FUNCTION. It's read by that key because
    # request.headers only maps dashed names, so looking up
    # "special_function" would never find it.
    def special_function?
      request.get_header("HTTP_SPECIAL_FUNCTION").present?
    end

    # A press means someone is standing there waiting for the panel to
    # change, so it renders now rather than on the schedule.
    def forced?
      request.headers["Update-Source"] == "button" || special_function?
    end

    def current_frame
      frame = current_device.current_frame

      if forced? || frame.nil? || pending?(frame)
        frame = FrameComposer.call(current_device)
        current_device.update_columns(refresh_requested_at: nil)
      end

      frame
    rescue StandardError => e
      Rails.logger.error("[Display] render failed: #{e.class}: #{e.message}")
      current_device.current_frame
    end

    def pending?(frame)
      current_device.refresh_requested_at.present? &&
        current_device.refresh_requested_at > frame.rendered_at
    end
end
