require "test_helper"

class DashboardItemTest < ActiveSupport::TestCase
  setup { @item = dashboard_items(:one) } # weather / current, one weather source

  test "a blank view falls back to the kind's first layout" do
    @item.view = ""
    @item.valid?
    assert_equal "current", @item.view

    fresh = dashboards(:one).dashboard_items.new(kind: "calendar", col: 5, row: 5)
    fresh.valid?
    assert_equal "today", fresh.view
  end

  test "a layout from another kind is rejected" do
    @item.view = "month" # a calendar layout
    assert_not @item.valid?
    assert_includes @item.errors.full_messages.to_sentence, "isn't available for Weather"
  end

  test "a source of the wrong provider type is rejected" do
    @item.sources = [ sources(:two) ] # iCal on a weather item

    assert_not @item.valid?
    assert_includes @item.errors.full_messages.to_sentence, "can't be used here"
  end

  test "a single-source kind refuses a second source" do
    second = Source.create!(
      name: "Other weather", refresh_seconds: 900,
      providable: WeatherProvider.new(latitude: 1, longitude: 2, units: "metric")
    )
    @item.sources = [ sources(:one), second ]

    assert_not @item.valid?
    assert_includes @item.errors.full_messages.to_sentence, "only one is allowed for Weather"
  end

  test "a multi-source kind accepts several" do
    item = dashboard_items(:two) # calendar
    second = Source.create!(
      name: "Other calendar", refresh_seconds: 900,
      providable: IcalProvider.new(ical_url: "https://example.com/b.ics")
    )
    item.sources = [ sources(:two), second ]

    assert item.valid?, item.errors.full_messages.to_sentence
  end

  test "a kind that takes no sources refuses them" do
    @item.kind = "clock"
    @item.view = "time"

    assert_not @item.valid?
    assert_includes @item.errors.full_messages.to_sentence, "aren't used by Clock"
  end

  test "setting falls back to the registry default" do
    assert_equal 5, @item.setting("day_count")
    assert_equal 6, @item.setting("hour_count")
  end

  test "setting casts what the form stored" do
    @item.settings = { "day_count" => "3", "hour_count" => "" }

    assert_equal 3, @item.setting("day_count")
    assert_equal 6, @item.setting("hour_count"), "blank falls back to the default"
  end

  test "a boolean setting can actually be turned off" do
    item = dashboard_items(:two) # calendar, show_times defaults to true
    assert_equal true, item.setting("show_times")

    item.settings = { "show_times" => "0" }
    assert_equal false, item.setting("show_times")
  end

  test "an unregistered key is returned untouched" do
    @item.settings = { "whatever" => "raw" }
    assert_equal "raw", @item.setting("whatever")
    assert_nil @item.setting("missing")
  end

  test "grid_style places the tile" do
    assert_equal "grid-column: 1 / span 4; grid-row: 1 / span 3;", @item.grid_style
  end

  test "an item may not extend past the grid" do
    @item.col_span = 9
    assert_not @item.valid?
    assert_includes @item.errors.full_messages.to_sentence, "extends past the grid"
  end
end
