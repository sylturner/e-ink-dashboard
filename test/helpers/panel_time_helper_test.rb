require "test_helper"

class PanelTimeHelperTest < ActionView::TestCase
  AFTERNOON = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-07 13:05")
  MORNING   = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-07 09:05")

  def event(starts_at, all_day: false)
    EventFeed::Event.new(title: "Standup", starts_at:, ends_at: starts_at + 1.hour, all_day:)
  end

  test "a 12-hour clock" do
    assert_equal "1:05", panel_time(AFTERNOON, :clock)
    assert_equal "1:05 PM", panel_time(AFTERNOON, :time)
    assert_equal "1 PM", panel_time(AFTERNOON, :hour)
  end

  test "a 24-hour clock" do
    AppSetting.current.update!(clock: "24h")

    assert_equal "13:05", panel_time(AFTERNOON, :clock)
    assert_equal "09:05", panel_time(MORNING, :time)
    assert_equal "13:00", panel_time(AFTERNOON.beginning_of_hour, :hour)
  end

  test "an event's time is its date and a compact time" do
    assert_equal "9/7 1:05p", event_time_label(event(AFTERNOON))
    assert_equal "9/7 9:05a", event_time_label(event(MORNING))

    AppSetting.current.update!(clock: "24h")
    assert_equal "9/7 13:05", event_time_label(event(AFTERNOON))
  end

  test "an all-day event says so" do
    assert_equal "9/7 All day", event_time_label(event(AFTERNOON.beginning_of_day, all_day: true))
  end
end
