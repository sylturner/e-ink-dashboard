require "test_helper"

class PanelTokensHelperTest < ActionView::TestCase
  # A Monday evening in September.
  NOW = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-07 19:36")

  def fill(text) = with_panel_tokens(text, now: NOW)

  test "fills the date and time tokens" do
    assert_equal "It&#39;s 7:36 PM on Sep 7", fill("It's {{CURRENT_TIME}} on {{CURRENT_DATE}}")
    assert_equal "Monday, September 7, 2026", fill("{{LONG_DATE}}")
    assert_equal "Monday · September · 2026", fill("{{WEEKDAY}} · {{MONTH}} · {{YEAR}}")
    assert_equal "Week 37", fill("Week {{WEEK_NUMBER}}")
  end

  test "the time follows the app's clock" do
    AppSetting.current.update!(clock: "24h")

    assert_equal "19:36", fill("{{CURRENT_TIME}}")
  end

  test "counts days to and from a date" do
    assert_equal "109 days to go", fill("{{DAYS_UNTIL:2026-12-25}} days to go")
    assert_equal "249", fill("{{DAYS_SINCE:2026-01-01}}")
    assert_equal "0", fill("{{ DAYS_UNTIL : 2026-09-07 }}")
    assert_equal "-6", fill("{{DAYS_UNTIL:2026-09-01}}")
  end

  test "greets by the time of day" do
    assert_equal "Good evening", fill("{{GREETING}}")
    assert_equal "Good morning", with_panel_tokens("{{GREETING}}", now: NOW.change(hour: 8))
    assert_equal "Good afternoon", with_panel_tokens("{{GREETING}}", now: NOW.change(hour: 13))
  end

  test "the server address, or nothing until it's set" do
    assert_equal "at ", fill("at {{SERVER_URL}}")

    AppSetting.current.update!(server_url: "http://dash.local:3000")
    assert_equal "at http://dash.local:3000", fill("at {{SERVER_URL}}")
  end

  test "an unknown token or a bad argument is drawn as typed" do
    assert_equal "{{WEATHER}} {{DAYS_UNTIL:someday}} {{DAYS_UNTIL}} {single}",
                 fill("{{WEATHER}} {{DAYS_UNTIL:someday}} {{DAYS_UNTIL}} {single}")
  end

  test "plain text is escaped and safe HTML is kept" do
    assert_equal "&lt;b&gt;7:36 PM", fill("<b>{{CURRENT_TIME}}")
    assert_equal "<b>7:36 PM</b>", fill("<b>{{CURRENT_TIME}}</b>".html_safe)
    assert_predicate fill("x"), :html_safe?
  end
end
