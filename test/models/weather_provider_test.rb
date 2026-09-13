require "test_helper"

class WeatherProviderTest < ActiveSupport::TestCase
  RESPONSE = {
    "current" => { "temperature_2m" => 71.6, "apparent_temperature" => 70.2,
                   "relative_humidity_2m" => 40, "weather_code" => 1, "is_day" => 1 },
    "hourly" => { "time" => %w[2026-09-07T11:00 2026-09-07T12:00 2026-09-07T13:00],
                  "temperature_2m" => [ 69.0, 70.1, 72.4 ], "weather_code" => [ 0, 0, 2 ],
                  "precipitation_probability" => [ 0, 0, 10 ], "is_day" => [ 1, 1, 1 ] },
    "daily" => { "time" => %w[2026-09-07], "weather_code" => [ 2 ],
                 "temperature_2m_max" => [ 75.0 ], "temperature_2m_min" => [ 60.0 ],
                 "precipitation_probability_max" => [ 10 ],
                 "sunrise" => %w[2026-09-07T06:52], "sunset" => %w[2026-09-07T19:31] }
  }.freeze

  test "hourly entries from this hour on carry their instant, in the source's zone" do
    provider = weather_providers(:two) # New York

    payload = travel_to(Time.utc(2026, 9, 7, 16, 30)) do # 12:30 in New York
      stub_method(Http, :get_json, returns: RESPONSE) { provider.fetch! }
    end

    assert_equal %w[2026-09-07T12:00:00-04:00 2026-09-07T13:00:00-04:00], payload["hourly"].map { it["at"] }
    assert_equal "2026-09-07T06:52:00-04:00", payload["sunrise"]
  end

  test "a new source starts with the app's units and zone" do
    AppSetting.current.update!(units: "metric", time_zone: "Europe/Berlin")

    AppSetting.current.apply do
      assert_equal({ units: "metric", time_zone: "Europe/Berlin" }, WeatherProvider.defaults)
    end
  end

  test "a source without a zone asks for the one its reply is read in" do
    provider = WeatherProvider.new(latitude: 1, longitude: 2, units: "metric")

    Time.use_zone("Asia/Tokyo") do
      assert_includes provider.send(:url), "timezone=Asia%2FTokyo"
    end
  end
end
