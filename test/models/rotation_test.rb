require "test_helper"

class RotationTest < ActiveSupport::TestCase
  ENTRIES = "Alice\n\n  Bob \nCarol\n".freeze

  def rotation(today, period: "daily", start: "2026-09-01", entries: ENTRIES)
    Rotation.new(entries:, period:, start:, today: Date.iso8601(today))
  end

  test "reads one entry a line, skipping blank ones" do
    assert_equal %w[Alice Bob Carol], rotation("2026-09-01").entries
  end

  test "moves on one entry a day from the start, wrapping round" do
    assert_equal %w[Alice Bob Carol Alice], %w[01 02 03 04].map { rotation("2026-09-#{it}").current }
    assert_equal "Carol", rotation("2026-08-31").current, "before the start it counts back"
  end

  test "moves on one entry a week, on the week's first day" do
    Date.beginning_of_week = :monday
    # Tuesday the 1st is in the week of Monday, August 31.
    assert_equal "Alice", rotation("2026-09-06", period: "weekly").current
    assert_equal "Bob", rotation("2026-09-07", period: "weekly").current
    assert_equal "Carol", rotation("2026-09-14", period: "weekly").current
  ensure
    Date.beginning_of_week = :monday
  end

  test "names the next entry, unless there's only one" do
    assert_equal "Bob", rotation("2026-09-01").upcoming
    assert_equal "Alice", rotation("2026-09-03").upcoming
    assert_nil rotation("2026-09-01", entries: "Alice").upcoming
  end

  test "without a start it starts today, and without entries it has nothing" do
    assert_equal "Alice", rotation("2026-10-10", start: "").current
    assert_not rotation("2026-09-01", entries: "\n").any?
    assert_nil rotation("2026-09-01", entries: "").current
  end
end
