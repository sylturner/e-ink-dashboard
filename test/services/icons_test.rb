require "test_helper"

class IconsTest < ActiveSupport::TestCase
  test "picks the day or night glyph from is_day" do
    assert_equal "day-cloudy", Icons.for_wmo(2, is_day: 1)
    assert_equal "night-alt-cloudy", Icons.for_wmo(2, is_day: 0)
  end

  test "uses the neutral glyph without is_day" do
    assert_equal "cloud", Icons.for_wmo(2)
  end

  test "falls back for missing and unknown codes" do
    assert_equal "na", Icons.for_wmo(nil)
    assert_equal "cloudy", Icons.for_wmo(42, is_day: 1)
  end

  test "short labels abbreviate thunderstorms" do
    assert_equal "Thunderstorms", Icons.label_for_wmo(95)
    assert_equal "T-Storms", Icons.label_for_wmo(95, short: true)
    assert_equal "Partly cloudy", Icons.label_for_wmo(2, short: true)
  end

  test "every mapped glyph has artwork" do
    Icons::OPEN_METEO.each_value do |table|
      table.each_value { |name| assert Icons::WEATHER.key?(name), "no glyph for #{name}" }
    end
  end
end
