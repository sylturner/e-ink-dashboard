require "test_helper"

class ScheduleSlotTest < ActiveSupport::TestCase
  setup do
    @assignment = device_dashboards(:one)
  end

  def slot(**attributes)
    ScheduleSlot.new(device_dashboard: @assignment, days: [ 1 ], from_time: "06:00", until_time: "11:00", **attributes)
  end

  test "times are kept as minutes after midnight and read back for a time field" do
    morning = slot(from_time: "06:30", until_time: "11:05:00")

    assert_equal 390, morning.from_minute
    assert_equal 665, morning.until_minute
    assert_equal "06:30", morning.from_time
    assert_equal "11:05", morning.until_time
  end

  test "a time that isn't one is blank" do
    %w[25:00 06:60 noon 6].each do |value|
      morning = slot(from_time: value)

      assert_nil morning.from_minute, value
      assert_not morning.valid?
      assert morning.errors[:from_time].any?
    end
  end

  test "days come from a form's checkboxes as sorted numbers" do
    assert_equal [ 0, 1, 5 ], slot(days: [ "", "5", "1", "0", "1" ]).days
  end

  test "it needs a day of the week" do
    assert_not slot(days: [ "" ]).valid?
    assert_not slot(days: [ 7 ]).valid?
    assert slot(days: ScheduleSlot::DAYS.to_a).valid?
  end

  test "it needs one of the panel's dashboards" do
    assert_not slot(device_dashboard: nil).valid?
  end

  test "it is on the panel's dashboard and goes when the dashboard is unassigned" do
    morning = slot.tap(&:save!)

    assert_equal dashboards(:one), morning.dashboard
    assert_equal devices(:one), morning.device
    assert_equal dashboards(:one).id, morning.dashboard_id

    assert_difference -> { ScheduleSlot.count }, -1 do
      @assignment.destroy
    end
  end
end
