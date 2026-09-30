require "test_helper"

class DashboardScheduleTest < ActiveSupport::TestCase
  Slot = Data.define(:id, :dashboard_id, :days, :from_minute, :until_minute)

  MORNING, MIDDAY, GROCERIES, EVENING = 1, 2, 3, 4
  EVERY_DAY = (0..6).to_a
  MONDAY = 1

  setup do
    @zone = ActiveSupport::TimeZone["America/New_York"]
    @morning   = Slot.new(id: 10, dashboard_id: MORNING, days: EVERY_DAY, from_minute: 6 * 60, until_minute: 11 * 60)
    @midday    = Slot.new(id: 11, dashboard_id: MIDDAY, days: EVERY_DAY, from_minute: 11 * 60, until_minute: 18 * 60)
    @groceries = Slot.new(id: 12, dashboard_id: GROCERIES, days: [ MONDAY ], from_minute: 12 * 60, until_minute: 17 * 60)
  end

  def schedule(*slots, default: nil)
    DashboardSchedule.new(slots, zone: @zone, default_dashboard_id: default)
  end

  # Monday, September 28, 2026, on the schedule's clock.
  def monday(hour, minute = 0) = @zone.local(2026, 9, 28, hour, minute)
  def tuesday(hour, minute = 0) = @zone.local(2026, 9, 29, hour, minute)

  test "there's no cue or change without slots" do
    empty = schedule(default: MORNING)

    assert empty.empty?
    assert_nil empty.cue_at(monday(9))
    assert_nil empty.next_switch(monday(9))
  end

  test "a slot is on from its start up to its end" do
    day = schedule(@morning, @midday)

    assert_equal MORNING, day.cue_at(monday(6)).dashboard_id
    assert_equal MORNING, day.cue_at(monday(10, 59)).dashboard_id
    assert_equal MIDDAY, day.cue_at(monday(11)).dashboard_id
    assert_equal @midday, day.cue_at(monday(11)).slot
  end

  test "an overlapping slot wins from when it starts, then gives way to the one it interrupted" do
    week = schedule(@morning, @midday, @groceries)

    assert_equal MIDDAY, week.cue_at(monday(11, 30)).dashboard_id
    assert_equal GROCERIES, week.cue_at(monday(12)).dashboard_id
    assert_equal GROCERIES, week.cue_at(monday(16, 59)).dashboard_id
    assert_equal MIDDAY, week.cue_at(monday(17)).dashboard_id
    assert_equal MIDDAY, week.cue_at(tuesday(12)).dashboard_id, "groceries is only on Mondays"
  end

  test "slots starting together go to the shorter, then to the one added first" do
    long  = Slot.new(id: 20, dashboard_id: MIDDAY, days: EVERY_DAY, from_minute: 12 * 60, until_minute: 18 * 60)
    short = Slot.new(id: 21, dashboard_id: GROCERIES, days: EVERY_DAY, from_minute: 12 * 60, until_minute: 13 * 60)
    twin  = Slot.new(id: 22, dashboard_id: EVENING, days: EVERY_DAY, from_minute: 12 * 60, until_minute: 13 * 60)

    assert_equal GROCERIES, schedule(twin, long, short).cue_at(monday(12, 30)).dashboard_id
  end

  test "between slots it's the default, or nothing when there isn't one" do
    assert_equal MORNING, schedule(@midday, default: MORNING).cue_at(monday(20)).dashboard_id
    assert_nil schedule(@midday).cue_at(monday(20)).dashboard_id
    assert_equal DashboardSchedule::DEFAULT_KEY, schedule(@midday).cue_at(monday(20)).key
  end

  test "an end at or before the start runs into the next day, and the same time is a whole day" do
    night   = Slot.new(id: 30, dashboard_id: EVENING, days: [ MONDAY ], from_minute: 22 * 60, until_minute: 6 * 60)
    all_day = Slot.new(id: 31, dashboard_id: GROCERIES, days: [ MONDAY ], from_minute: 0, until_minute: 0)

    assert_equal EVENING, schedule(night).cue_at(tuesday(5, 59)).dashboard_id, "it started on Monday"
    assert_nil schedule(night).cue_at(tuesday(6)).dashboard_id
    assert_nil schedule(night).cue_at(tuesday(23)).dashboard_id, "it only starts on Mondays"

    assert_equal GROCERIES, schedule(all_day).cue_at(monday(0)).dashboard_id
    assert_equal GROCERIES, schedule(all_day).cue_at(monday(23, 59)).dashboard_id
    assert_nil schedule(all_day).cue_at(tuesday(0)).dashboard_id
  end

  test "each occurrence of a slot is its own stretch" do
    day = schedule(@morning)

    assert_equal day.cue_at(monday(7)).key, day.cue_at(monday(10)).key
    assert_not_equal day.cue_at(monday(7)).key, day.cue_at(tuesday(7)).key
  end

  test "times are read on the schedule's clock" do
    utc = monday(6).utc

    assert_equal MORNING, schedule(@morning).cue_at(utc).dashboard_id
  end

  test "changes come in order, skipping boundaries that change nothing" do
    week = schedule(@morning, @midday, @groceries, default: EVENING)

    changes = week.changes(monday(5)).first(6).map { [ it.at, it.cue.dashboard_id ] }

    assert_equal [
      [ monday(6), MORNING ],
      [ monday(11), MIDDAY ],
      [ monday(12), GROCERIES ],
      [ monday(17), MIDDAY ],
      [ monday(18), EVENING ],
      [ tuesday(6), MORNING ]
    ], changes
  end

  test "the next switch skips a gap without a default, which leaves the panel as it is" do
    week = schedule(@morning)

    assert_equal [ monday(11), nil ], week.changes(monday(7)).first.then { [ it.at, it.cue.dashboard_id ] }
    assert_equal [ tuesday(6), MORNING ], week.next_switch(monday(7)).then { [ it.at, it.cue.dashboard_id ] }
  end

  test "a slot once a week is still found from any day" do
    week = schedule(@groceries)

    assert_equal @zone.local(2026, 10, 5, 12), week.next_switch(monday(13)).at
  end

  test "a slot starts at its wall-clock time on either side of a clock change" do
    # Clocks go back at 2:00 on Sunday, November 1, 2026.
    day = schedule(@morning)

    assert_equal @zone.local(2026, 11, 1, 6), day.next_switch(@zone.local(2026, 10, 31, 12)).at
    assert_equal @zone.local(2026, 11, 2, 6), day.next_switch(@zone.local(2026, 11, 1, 12)).at
  end
end
