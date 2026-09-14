require "test_helper"

class DevicesHelperTest < ActionView::TestCase
  include ApplicationHelper
  include NavigationHelper

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
end
