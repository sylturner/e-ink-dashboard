require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    @time = Time.zone.parse("2026-09-12 09:00")
  end

  test "a past time reads as ago, with the exact time in datetime" do
    travel_to @time + 2.hours do
      @rendered = relative_time_tag(@time)
    end

    assert_select "time[datetime=?]", @time.iso8601, "about 2 hours ago"
  end

  test "a future time reads as in" do
    travel_to @time - 5.minutes do
      @rendered = relative_time_tag(@time)
    end

    assert_select "time", "in 5 minutes"
  end

  test "no time gives the never text" do
    assert_equal "Never", relative_time_tag(nil)
    assert_equal "Not yet", relative_time_tag(nil, never: "Not yet")
  end

  test "a status badge is tinted by its tone" do
    @rendered = status_badge("OK", :success)

    assert_select "span.badge.bg-success-subtle.text-success-emphasis", "OK"
  end
end
