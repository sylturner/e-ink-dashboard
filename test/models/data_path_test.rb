require "test_helper"

class DataPathTest < ActiveSupport::TestCase
  DATA = {
    "state" => "21.5",
    "attributes" => { "friendly_name" => "Kitchen", "unit" => "°C" },
    "sensor.outside" => { "state" => "12" },
    "departures" => [ { "route" => "7", "time" => "2026-09-06T09:12:00-04:00" }, { "route" => "12" } ]
  }.freeze

  test "walks keys and list indexes joined by dots" do
    assert_equal "21.5", DataPath.dig(DATA, "state")
    assert_equal "Kitchen", DataPath.dig(DATA, "attributes.friendly_name")
    assert_equal "12", DataPath.dig(DATA, "departures.1.route")
    assert_equal "12", DataPath.dig(DATA, "departures.-1.route")
  end

  test "finds a key with dots of its own whole" do
    assert_equal "12", DataPath.dig(DATA, "sensor.outside.state")
    assert_equal "Ada", DataPath.dig({ "dc:creator" => "Ada" }, "dc:creator")
  end

  test "a path that leads nowhere is nil, and a blank one is the data" do
    assert_nil DataPath.dig(DATA, "attributes.missing")
    assert_nil DataPath.dig(DATA, "state.deeper")
    assert_nil DataPath.dig(DATA, "departures.first")
    assert_nil DataPath.dig(nil, "state")
    assert_same DATA, DataPath.dig(DATA, "")
  end

  test "lists every value by its path, a list by its first entry" do
    assert_equal [
      [ "state", "21.5" ], [ "attributes.friendly_name", "Kitchen" ], [ "attributes.unit", "°C" ],
      [ "sensor.outside.state", "12" ], [ "departures.0.route", "7" ], [ "departures.0.time", "2026-09-06T09:12:00-04:00" ]
    ], DataPath.leaves(DATA)

    assert_equal [ [ "tags", %w[a b] ] ], DataPath.leaves({ "tags" => %w[a b] })
    assert_equal [ [ "", 5 ] ], DataPath.leaves(5)
    assert_equal 2, DataPath.leaves(DATA, limit: 2).size
  end
end
