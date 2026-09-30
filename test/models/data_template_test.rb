require "test_helper"

class DataTemplateTest < ActiveSupport::TestCase
  ZONE = ActiveSupport::TimeZone["America/New_York"]

  test "reads a token's path, filter and argument" do
    assert_equal DataTemplate::Token.new(path: "a.b", filter: "round", argument: "1"), DataTemplate.token("a.b|round:1")
    assert_equal DataTemplate::Token.new(path: "a", filter: nil, argument: nil), DataTemplate.token("a")
    assert_nil DataTemplate.token("a|shout").filter
  end

  test "a path starts at the entry, or at the top of the data after $." do
    root = { "stop" => "Main St", "departures" => [ { "route" => "7" } ] }
    entry = root["departures"].first

    assert_equal "7", DataTemplate.lookup("route", entry, root:)
    assert_equal "Main St", DataTemplate.lookup("$.stop", entry, root:)
    assert_same root, DataTemplate.lookup("$", entry, root:)
  end

  test "the entries of a list, or the data once" do
    data = { "departures" => [ 1, 2, 3 ], "stop" => "Main St" }

    assert_equal [ data ], DataTemplate.entries(data, "", limit: 5)
    assert_equal [ 1, 2 ], DataTemplate.entries(data, "departures", limit: 2)
    assert_equal [ 1, 2, 3 ], DataTemplate.entries(data, "{departures}", limit: 5)
    assert_equal [], DataTemplate.entries(data, "stop", limit: 5)
    assert_equal 50, DataTemplate.entries({ "l" => (1..99).to_a }, "l", limit: 500).size
  end

  test "draws values as text" do
    assert_equal "21", DataTemplate.text(21.0)
    assert_equal "21.5", DataTemplate.text(21.5)
    assert_equal "a, b, 3", DataTemplate.text([ "a", "b", 3 ])
    assert_equal "", DataTemplate.text([ { "a" => 1 } ])
    assert_equal "", DataTemplate.text({ "a" => 1 })
    assert_equal "", DataTemplate.text(nil)
    assert_equal "false", DataTemplate.text(false)
  end

  test "rounds and changes case" do
    assert_equal "21.5", DataTemplate.filter("21.456", DataTemplate.token("x|round:1"))
    assert_equal "21", DataTemplate.filter(21.456, DataTemplate.token("x|round"))
    assert_equal "on", DataTemplate.filter("on", DataTemplate.token("x|round"))
    assert_equal "ON", DataTemplate.filter("on", DataTemplate.token("x|upcase"))
    assert_equal "off", DataTemplate.filter("OFF", DataTemplate.token("x|downcase"))
  end

  test "reads a time from ISO 8601, or seconds or milliseconds since 1970" do
    at = ZONE.parse("2026-09-06 09:12")

    assert_equal at, DataTemplate.moment("2026-09-06T13:12:00Z", ZONE)
    assert_equal at, DataTemplate.moment(at.to_i, ZONE)
    assert_equal at, DataTemplate.moment(at.to_i * 1000, ZONE)
    assert_equal ZONE, DataTemplate.moment(at.to_i, ZONE).time_zone
    assert_nil DataTemplate.moment("soon", ZONE)
    assert_nil DataTemplate.moment(nil, ZONE)
  end
end
