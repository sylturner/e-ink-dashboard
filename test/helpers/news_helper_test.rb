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
end
