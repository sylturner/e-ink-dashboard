require "test_helper"

class NewsHelperTest < ActionView::TestCase
  include PanelTimeHelper
  NOW = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-16 12:00")

  test "a byline names the source as it was named here, and how long ago" do
    story = { "source" => "\"site:reuters.com\" - Google News", "source_name" => "Reuters", "published_at" => "2026-09-16T14:00:00Z" }

    assert_equal "Reuters · 2h", news_byline(story, NOW)
    assert_equal "Reuters", news_byline(story.except("published_at"), NOW)
    assert_nil news_byline({}, NOW)
  end

  def event(starts_at, all_day: false)
    EventFeed::Event.new(title: "Standup", starts_at:, ends_at: starts_at + 1.hour, all_day:)
  end

  test "an upcoming event says its day and time as a newspaper prints them" do
    assert_equal "Today · Now", newspaper_event_when(event(NOW - 30.minutes), NOW)
    assert_equal "Today · 3:00 PM", newspaper_event_when(event(NOW + 3.hours), NOW)
    assert_equal "Tomorrow · All day", newspaper_event_when(event(NOW.tomorrow.beginning_of_day, all_day: true), NOW)
    assert_equal "Friday · 9:00 AM", newspaper_event_when(event(NOW + 45.hours), NOW)
    assert_equal "Today · All day", newspaper_event_when(event((NOW - 1.day).beginning_of_day, all_day: true), NOW), "a two-day event under way"
  end
end
