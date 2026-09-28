# A Wi-Fi network as the text of a QR code a phone's camera joins it from:
# WIFI:T:WPA;S:<name>;P:<password>;H:true;; (the format ZXing defined, which
# Android and iOS both read).
class WifiNetwork
  SECURITIES = %w[WPA WEP nopass].freeze

  attr_reader :ssid, :password, :security

  def initialize(ssid:, password: "", security: "WPA", hidden: false)
    @ssid     = ssid.to_s
    @password = password.to_s
    @security = SECURITIES.include?(security.to_s) ? security.to_s : "WPA"
    @hidden   = ActiveModel::Type::Boolean.new.cast(hidden)
  end

  def valid?
    ssid.present?
  end

  def open?
    security == "nopass"
  end

  def hidden?
    @hidden == true
  end

  def to_s
    fields = [ "T:#{security}", "S:#{escape(ssid)}" ]
    fields << "P:#{escape(password)}" unless open?
    fields << "H:true" if hidden?

    "WIFI:#{fields.join(';')};;"
  end

  private

    # The format's special characters are taken literally after a backslash.
    def escape(text)
      text.gsub(/([\\;,:"])/) { "\\#{it}" }
    end
end
