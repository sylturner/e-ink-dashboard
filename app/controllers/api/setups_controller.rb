# GET /api/setup
#
# A panel with no API key sends its MAC and is given one. A panel that is
# reset or re-flashed gets its old key back and keeps its dashboards.
class Api::SetupsController < Api::BaseController
  def show
    # Anything but a 200 shows "MAC not registered" on a TRMNL.
    return head(:not_found) if mac.blank?

    device = Device.enroll!(mac: mac, attributes: hardware_attributes.merge(AppSetting.current.panel_defaults))
    # The firmware asks again on every wake until this is filled in.
    friendly_id = device.claim_code.presence || mac.delete(":").last(6).upcase

    render json: {
      status: 200,
      api_key: device.token,
      friendly_id: friendly_id,
      image_url: nil,
      message: t("api.setup.message", code: friendly_id)
    }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[Setup] #{e.message}")
    head :not_found
  end

  private

    # What the panel reports about itself. TRMNL's firmware sends no size,
    # so a new row keeps the column defaults: an 800x480 1-bit BMP panel,
    # which is what a TRMNL is. No time zone: a panel follows the app's
    # until it is given one.
    def hardware_attributes
      width, height = header_int("Width"), header_int("Height")
      size = width && height ? { width: width, height: height, image_format: Device.image_format_for(width, height) } : {}

      { firmware_version: request.headers["FW-Version"].presence }.compact.merge(size)
    end
end
