require "test_helper"

class CountdownsHelperTest < ActionView::TestCase
  NOW = ActiveSupport::TimeZone["America/New_York"].parse("2026-12-22 09:30")

  def countdown(date, **options)
    Countdown.new(date:, now: NOW, **options)
  end

  test "writes what's left, singular or plural" do
    assert_equal "1 day", countdown_time(days: 1)
    assert_equal "3 days and 1 hour", countdown_time(days: 3, hours: 1)
    assert_equal "20 minutes", countdown_time(minutes: 20)
  end

  test "a sentence without a name" do
    assert_equal "3 days to go", countdown_sentence(countdown("2026-12-25"), label: "")
    assert_equal "Today!", countdown_sentence(countdown("2026-12-22"), label: "")
    assert_equal "1 day ago", countdown_sentence(countdown("2026-12-21"), label: "")
  end

  test "the big number's unit and the line under it" do
    assert_equal "days and 2 hours", countdown_unit(days: 3, hours: 2)
    assert_equal "hour", countdown_unit(hours: 1)
    assert_equal "to go", countdown_label(countdown("2026-12-25"), label: "")
    assert_equal "since Christmas", countdown_label(countdown("2026-12-20"), label: "Christmas")
  end
end
