require "test_helper"

class CountdownTest < ActiveSupport::TestCase
  ZONE = ActiveSupport::TimeZone["America/New_York"]
  NOW  = ZONE.parse("2026-12-22 09:30")

  def countdown(date, time: nil, unit: "days", now: NOW)
    Countdown.new(date:, time:, unit:, now:)
  end

  test "counts calendar days to a day ahead" do
    assert_equal :ahead, countdown("2026-12-25").state
    assert_equal({ days: 3 }, countdown("2026-12-25").remaining)
  end

  test "is today all of the day, and counts days since after it" do
    assert_equal :today, countdown("2026-12-22").state
    assert_equal :past, countdown("2026-12-20").state
    assert_equal 2, countdown("2026-12-20").days_since
  end

  test "counts days and hours up to a time, leaving out a zero" do
    assert_equal({ days: 3, hours: 2 }, countdown("2026-12-25", time: "11:30", unit: "hours").remaining)
    assert_equal({ days: 3 }, countdown("2026-12-25", time: "09:30", unit: "hours").remaining)
    assert_equal({ hours: 5 }, countdown("2026-12-22", time: "14:45", unit: "hours").remaining)
  end

  test "counts minutes when less than an hour is left" do
    assert_equal({ minutes: 20 }, countdown("2026-12-22", time: "09:50", unit: "hours").remaining)
    assert_equal({ minutes: 1 }, countdown("2026-12-22", time: "09:30", unit: "hours", now: NOW - 10.seconds).remaining)
  end

  test "in hours, the day is ahead until its time, then today" do
    assert_equal :ahead, countdown("2026-12-22", time: "10:00", unit: "hours").state
    assert_equal :today, countdown("2026-12-22", time: "09:00", unit: "hours").state
    assert_equal :today, countdown("2026-12-22", unit: "hours").state
  end

  test "counts to the time in the panel's zone" do
    tokyo = ActiveSupport::TimeZone["Asia/Tokyo"].parse("2026-12-24 22:00")

    assert_equal({ hours: 2 }, countdown("2026-12-25", unit: "hours", now: tokyo).remaining)
  end

  test "a date it can't read isn't valid, and an unknown unit counts days" do
    assert_not countdown("").valid?
    assert_not countdown("12/25/2026").valid?
    assert_equal({ days: 3 }, countdown("2026-12-25", time: "11:30", unit: "weeks").remaining)
  end
end
