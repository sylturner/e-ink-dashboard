require "test_helper"

class DataTilesHelperTest < ActionView::TestCase
  NOW = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-06 09:00")

  DATA = {
    "state" => "21.456",
    "attributes" => { "friendly_name" => "Kitchen", "unit" => "°C" },
    "updated" => "2026-09-06T12:00:00Z",
    "departures" => [ { "route" => "7", "at" => "2026-09-06T09:12:00-04:00" } ]
  }.freeze

  def line(format, scope = DATA)
    data_line(format, scope, root: DATA, now: NOW)
  end

  test "fills paths and filters" do
    assert_equal "Kitchen: 21.5°C", line("{attributes.friendly_name}: {state|round:1}{attributes.unit}")
    assert_equal "KITCHEN", line("{attributes.friendly_name|upcase}")
  end

  test "draws times on the panel's clock" do
    assert_equal "8:00 AM", line("{updated|time}")
    assert_equal "Sep 6", line("{updated|date}")
    assert_equal "1h", line("{updated|age}")
    assert_equal "Route 7 in 12m", line("Route {route} in {at|until}", DATA["departures"].first)
  end

  test "inside a list's entry, $. reaches the top of the data" do
    assert_equal "7 · Kitchen", line("{route} · {$.attributes.friendly_name}", DATA["departures"].first)
  end

  test "a time filter on something that isn't a time draws it as it is" do
    assert_equal "21.456", line("{state|time}")
  end

  test "a line of empty values isn't drawn" do
    assert_nil line("Now: {missing}")
  end

  test "splits a tile's lines" do
    assert_equal [ "{a}", "b {c}" ], data_formats("{a}\n\n  b {c}  \n")
  end
end
