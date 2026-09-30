require "test_helper"

class DevicesHelperTest < ActionView::TestCase
  include ApplicationHelper
  include NavigationHelper
  include PanelTimeHelper

  setup do
    @device = devices(:one) # 800x480 1-bit bmp, 84% at 3.91 V, -62 dBm, 5-minute daytime sleep
  end

  test "the spec gives the size, depth and format, and the rotation when there is one" do
    assert_equal "800×480 · 1-bit bmp", device_spec(@device)
    assert_equal "800×480 · 2-bit png · 90°", device_spec(devices(:two))
  end

  test "a panel checking in on schedule" do
    travel_to @device.last_seen_at + 1.minute do
      @rendered = device_check_in(@device)
    end

    assert_select ".badge.bg-success-subtle", "Checked in"
    assert_select "time[datetime=?]", @device.last_seen_at.iso8601, "1 minute ago"
  end

  test "a panel that has missed its check-ins is overdue" do
    travel_to @device.last_seen_at + 1.day do
      @rendered = device_check_in(@device)
    end

    assert_select ".badge.bg-warning-subtle", "Overdue"
  end

  test "a panel that has never checked in says so" do
    @rendered = device_check_in(Device.new)

    assert_select ".badge", "Never checked in"
    assert_select "time", 0
  end

  test "the next check-in is when it's due, or when it was due once that has passed" do
    due = @device.next_check_in_at

    travel_to due - 2.minutes do
      @rendered = device_next_check_in(@device)
    end
    assert_select "time[datetime=?]", due.iso8601, "in 2 minutes"

    travel_to due + 1.hour do
      @rendered = device_next_check_in(@device)
    end
    assert_match(/\AWas due <time[^>]*>about 1 hour ago<\/time>\z/, @rendered)

    assert_equal "When it first connects", device_next_check_in(Device.new)
  end

  test "the battery shows its charge and voltage, with an icon to match" do
    @rendered = device_battery(@device)
    assert_select "svg[aria-hidden=true] use[href$=?]", "#cil-battery-full"
    assert_includes @rendered, "84% (3.91 V)"

    @device.assign_attributes(battery_percent: 12, battery_voltage: nil)
    @rendered = device_battery(@device)
    assert_select "svg use[href$=?]", "#cil-battery-alert"
    assert_includes @rendered, "12%"
    assert_not_includes @rendered, " V)"
  end

  test "the signal is given in words and dBm, with bars to match" do
    @rendered = device_signal(@device)
    assert_select "svg use[href$=?]", "#cil-wifi-signal-3"
    assert_includes @rendered, "Good (-62 dBm)"

    @device.wifi_rssi = -90
    assert_includes device_signal(@device), "Very weak (-90 dBm)"
  end

  test "telemetry the panel hasn't sent isn't reporting" do
    assert_includes device_battery(Device.new), "Not reporting"
    assert_includes device_signal(Device.new), "Not reporting"
    assert_includes device_firmware(Device.new), "Not reporting"
    assert_equal "1.0.0", device_firmware(@device)
  end

  test "hour options read as 24-hour clock times" do
    assert_equal [ [ "00:00", 0 ], [ "24:00", 24 ] ], hour_options(0..24).values_at(0, -1)
  end

  test "a saved hour outside the range stays a choice, in order" do
    assert_equal [ 0, 1, 2 ], hour_options(1..2, 0).map(&:last)
    assert_equal [ 1, 2 ], hour_options(1..2, 2).map(&:last)
  end

  # --- the schedule ---

  def slot(days, from, till)
    ScheduleSlot.new(days:, from_time: from, until_time: till)
  end

  test "a slot's days are said as briefly as they can be" do
    assert_equal "Every day", schedule_slot_days((0..6).to_a)
    assert_equal "Weekdays", schedule_slot_days([ 1, 2, 3, 4, 5 ])
    assert_equal "Weekends", schedule_slot_days([ 6, 0 ])
    assert_equal "Mondays", schedule_slot_days([ 1 ])
    AppSetting.current.update!(week_start: "sunday")
    AppSetting.current.apply { assert_equal "Sun, Mon, Fri", schedule_slot_days([ 5, 1, 0 ]) }
  end

  test "listed days follow the app's week" do
    AppSetting.current.update!(week_start: "monday")

    AppSetting.current.apply do
      assert_equal "Mon, Fri, Sun", schedule_slot_days([ 5, 1, 0 ])
      assert_equal [ "Mon", "Monday", 1 ], schedule_day_options.first
    end
  end

  test "a slot's times are on the app's clock, and say when they run past midnight" do
    assert_equal "Weekdays, 6:00 AM to 11:00 AM", schedule_slot_when(slot([ 1, 2, 3, 4, 5 ], "06:00", "11:00"))
    assert_equal "10:00 PM to 6:00 AM the next day", schedule_slot_times(slot([ 1 ], "22:00", "06:00"))
    assert_equal "6:00 PM to 12:00 AM", schedule_slot_times(slot([ 1 ], "18:00", "00:00"))
    assert_equal "all day", schedule_slot_times(slot([ 1 ], "00:00", "00:00"))

    AppSetting.current.update!(clock: "24h")
    assert_equal "06:00 to 11:00", schedule_slot_times(slot([ 1 ], "06:00", "11:00"))
  end

  test "a switch is said from the day it's seen" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    now = zone.local(2026, 9, 28, 9) # a Monday

    assert_equal "at 11:00 AM", schedule_switch_time(zone.local(2026, 9, 28, 11), now)
    assert_equal "tomorrow at 6:00 AM", schedule_switch_time(zone.local(2026, 9, 29, 6), now)
    assert_equal "Thursday at 6:00 AM", schedule_switch_time(zone.local(2026, 10, 1, 6), now)
    assert_equal "next Monday at 8:00 AM", schedule_switch_time(zone.local(2026, 10, 5, 8), now)
  end

  test "the status line says what the schedule wants and what comes next" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    office = @device.device_dashboards.create!(dashboard: dashboards(:two), position: 1)
    office.schedule_slots.create!(days: ScheduleSlot::DAYS.to_a, from_time: "11:00", until_time: "18:00")
    @device.update!(default_dashboard: dashboards(:one))

    assert_nil device_schedule(devices(:two)), "no schedule, no line"

    assert_equal "Next: Office at 11:00 AM.", device_schedule(@device, zone.local(2026, 9, 28, 9))
    assert_equal "Switches to Office when it next wakes. Next: Kitchen at 6:00 PM.",
                 device_schedule(@device, zone.local(2026, 9, 28, 12))

    @device.apply_schedule!(zone.local(2026, 9, 28, 12))
    @device.update!(dashboard: dashboards(:one))
    assert_equal "Switched by hand from Office. Next: Kitchen at 6:00 PM.",
                 device_schedule(@device.reload, zone.local(2026, 9, 28, 13))
  end
end
