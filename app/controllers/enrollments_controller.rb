# Device self-enrollment. A panel boots with no token, posts its MAC, and
# is handed a token of its own.
#
# Deliberately unauthenticated: this runs on a home LAN, so anything that
# can reach it is already trusted. Enrollment is idempotent by MAC, so
# the worst a stray caller does is create a Device row that shows a
# setup screen until someone claims it.
class EnrollmentsController < ApplicationController
  skip_forgery_protection

  def create
    return head :bad_request if mac.blank?

    device = Device.enroll!(mac: mac, attributes: enrollment_attributes)

    # Plain text, so the firmware needs no JSON parser.
    render plain: device.token
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[Enroll] #{e.message}")
    head :unprocessable_content
  end

  private


    def mac
      request.headers["X-Device-Mac"].to_s.downcase.strip
    end

    # What the panel reports about itself, on the app's schedule. No time
    # zone: a panel follows the app's until it is given one.
    def enrollment_attributes
      {
        width: header_int("X-Device-Width") || 800,
        height: header_int("X-Device-Height") || 480,
        bit_depth: header_int("X-Device-Bit-Depth") || 1,
        image_format: request.headers["X-Device-Format"].presence || "bmp",
        firmware_version: request.headers["X-Firmware-Version"].presence
      }.compact.merge(AppSetting.current.panel_defaults)
    end

    def header_int(name)
      value = request.headers[name]
      value.presence && value.to_i
    end
end
