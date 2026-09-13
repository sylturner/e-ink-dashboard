class WeatherProvider < ApplicationRecord
  include Providable

  provides label:           "Weather",
           icon:            "cil-cloud",
           description:     "Current conditions and forecasts from Open-Meteo for a place you choose.",
           attributes:      %i[latitude longitude units time_zone],
           refresh_seconds: 900

  ENDPOINT = "https://api.open-meteo.com/v1/forecast".freeze
  UNITS    = %w[imperial metric].freeze

  validates :latitude, :longitude, presence: true
  validates :units, inclusion: { in: UNITS }

  def self.defaults
    { units: AppSetting.current.units, time_zone: Time.zone.tzinfo.name }
  end

  def detail
    "#{latitude}, #{longitude}"
  end

  def fetch!
    data = Http.get_json(url)
    zone = time_zone.presence || Time.zone.name

    {
      "units"   => units,
      "current" => current(data),
      "daily"   => daily(data, zone),
      "hourly"  => hourly(data, zone),
      "sunrise" => iso_time(data.dig("daily", "sunrise", 0), zone),
      "sunset"  => iso_time(data.dig("daily", "sunset", 0), zone)
    }
  end

  private

  def url
    params = {
      latitude: latitude,
      longitude: longitude,
      current: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day",
      hourly: "temperature_2m,weather_code,precipitation_probability,is_day",
      daily: "weather_code,temperature_2m_max,temperature_2m_min," \
             "precipitation_probability_max,sunrise,sunset",
      # The zone the reply is parsed in (see #fetch!), so the two agree.
      timezone: time_zone.presence || Time.zone.tzinfo.name,
      forecast_days: 7,
      temperature_unit: imperial? ? "fahrenheit" : "celsius",
      wind_speed_unit: imperial? ? "mph" : "kmh",
      precipitation_unit: imperial? ? "inch" : "mm"
    }
    "#{ENDPOINT}?#{params.to_query}"
  end

  def imperial?
    units == "imperial"
  end

  def current(data)
    c    = data["current"] || {}
    code = c["weather_code"]

    {
      "temp"       => c["temperature_2m"]&.round,
      "feels_like" => c["apparent_temperature"]&.round,
      "humidity"   => c["relative_humidity_2m"]&.round,
      "icon"       => Icons.for_wmo(code, is_day: c["is_day"]),
      "label"      => Icons.label_for_wmo(code)
    }
  end

  def daily(data, zone)
    d = data["daily"] || {}
    Array(d["time"]).each_with_index.map do |date, i|
      code = d.dig("weather_code", i)
      {
        "date"   => date,
        "day"    => Date.parse(date).strftime("%a"),
        "high"   => d.dig("temperature_2m_max", i)&.round,
        "low"    => d.dig("temperature_2m_min", i)&.round,
        "precip" => d.dig("precipitation_probability_max", i),
        # Daily codes summarize the day, and there's no is_day to go on.
        "icon"   => Icons.for_wmo(code, is_day: 1),
        "label"  => Icons.label_for_wmo(code, short: true)
      }
    end
  end

  def hourly(data, zone)
    h   = data["hourly"] || {}
    tz  = Time.find_zone(zone) || Time.zone
    now = Time.current.in_time_zone(tz)

    Array(h["time"]).each_with_index.filter_map do |stamp, i|
      # Open-Meteo returns naive timestamps already in the requested
      # zone, so they must be parsed in that zone rather than UTC.
      at = tz.parse(stamp)
      next if at.nil? || at < now.beginning_of_hour

      code = h.dig("weather_code", i)
      {
        # An instant with its offset, so the panel formats it on its own
        # clock (PanelTimeHelper) and still in this source's zone.
        "at"     => at.iso8601,
        "temp"   => h.dig("temperature_2m", i)&.round,
        "precip" => h.dig("precipitation_probability", i),
        "icon"   => Icons.for_wmo(code, is_day: h.dig("is_day", i)),
        "label"  => Icons.label_for_wmo(code, short: true)
      }
    end.first(24)
  end

  def iso_time(stamp, zone)
    return nil if stamp.blank?

    tz = Time.find_zone(zone) || Time.zone
    tz.parse(stamp).iso8601
  end
end
