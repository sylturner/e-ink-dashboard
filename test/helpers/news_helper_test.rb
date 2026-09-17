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

  test "cut-out letters keep the name, each in a treatment" do
    letters = Nokogiri::HTML.fragment(ransom_letters("Zine Z"))

    assert_equal "Zine Z", letters.text
    assert_equal 5, letters.css(".ransom").size
    assert_equal 1, letters.css(".ransom-space").size
    assert_equal ransom_letters("Zine Z"), ransom_letters("Zine Z"), "the same name always cuts out the same"
  end

  test "pixel art is drawn in whole-pixel rects" do
    star = Nokogiri::HTML.fragment(pixel_art(:star)).at_css("svg")

    assert_equal "crispEdges", star["shape-rendering"]
    assert star.css("rect").all? { |rect| %w[x y width height].all? { rect[it].match?(/\A\d+\z/) } }
  end

  test "shifted letters keep a headline's words whole, and count on across them" do
    letters = Nokogiri::HTML.fragment(shifted_letters("Big news", "wave"))

    assert_equal "Big news", letters.text
    assert_equal %w[Big news], letters.css(".shift-word").map(&:text)
    assert_equal "shift shift-wave-3", letters.css(".shift")[3]["class"], "the wave carries on into the second word"
    assert_empty letters.css(".shift--inverted"), "a wave inverts nothing"
  end

  test "a pattern that inverts letters inverts only the headline's first" do
    letters = Nokogiri::HTML.fragment(shifted_letters("Glitch in the matrix, glitch again", "glitch"))

    assert_equal [ "G" ], letters.css(".shift--inverted").map(&:text)
  end
end
