require "test_helper"

class RendersControllerTest < ActionDispatch::IntegrationTest
  # Sunday, so the week view's window is the interesting case.
  NOW = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-06 09:00")

  setup do
    @dashboard = dashboards(:two)
    @item      = dashboard_items(:two) # calendar, cols 1-6 rows 1-4
    @source    = sources(:two)         # iCal

    @source.update!(payload: { "events" => [
      { "uid" => "a", "title" => "Labor Day", "all_day" => true,
        "start_on" => "2026-09-07", "end_on" => "2026-09-07",
        "starts_at" => "2026-09-07T00:00:00Z", "ends_at" => "2026-09-08T00:00:00Z",
        "calendar" => "Holidays" },
      { "uid" => "b", "title" => "Dentist", "all_day" => false,
        "starts_at" => "2026-09-10T18:00:00Z", "ends_at" => "2026-09-10T19:00:00Z",
        "calendar" => "Personal" },
      { "uid" => "c", "title" => "Standup", "all_day" => false,
        "starts_at" => "2026-09-06T13:00:00Z", "ends_at" => "2026-09-06T13:30:00Z",
        "calendar" => "Work" }
    ] })
  end

  def render_view(view)
    @item.update!(view: view)
    travel_to(NOW) { get "/render/dashboard", params: { dashboard_id: @dashboard.id } }
    assert_response :success
    response.body
  end

  test "today shows only today's events" do
    body = render_view("today")

    assert_includes body, "Standup"
    assert_not_includes body, "Labor Day"
    assert_not_includes body, "Dentist"
  end

  test "tomorrow shows the following day" do
    body = render_view("tomorrow")

    assert_includes body, "Labor Day"
    assert_not_includes body, "Standup"
  end

  test "next_events lists upcoming entries in order" do
    body = render_view("next_events")

    assert_operator body.index("Standup"), :<, body.index("Labor Day")
    assert_operator body.index("Labor Day"), :<, body.index("Dentist")
  end

  test "next_days groups by day and heads today as Today" do
    @item.update!(settings: { "day_count" => "5" })
    body = render_view("next_days")

    assert_includes body, "Today"
    assert_includes body, "Mon 7"
    assert_includes body, "Standup"
    assert_includes body, "Labor Day"
  end

  # Rails' default week ends on Sunday, which would make "this week"
  # exactly one day long whenever the panel is read on a Sunday.
  test "week runs to Saturday even when read on a Sunday" do
    body = render_view("week")

    assert_includes body, "Standup",   "today should be in the week"
    assert_includes body, "Labor Day", "Monday should be in the week"
    assert_includes body, "Dentist",   "Thursday should be in the week"
  end

  test "month draws a grid with today inverted and outside days marked" do
    body = render_view("month")

    assert_select "div.month-cell", 35
    assert_select "div.month-cell--today", 1
    assert_select "div.month-cell--outside", 5
    assert_select "span.month-dots", 3 # 6th, 7th and 10th carry events
  end

  test "show_times can be switched off" do
    @item.update!(settings: { "show_times" => "0" })
    body = render_view("today")

    assert_includes body, "Standup"
    assert_not_includes body, "9:00"
  end

  test "an empty day says so rather than rendering nothing" do
    @source.update!(payload: { "events" => [] })
    body = render_view("today")

    assert_includes body, "Nothing today"
  end

  # A marker is only worth its pixels when several calendars are merged.
  test "a tile merging two calendars marks which one each event is from" do
    second = Source.create!(
      name: "Family", refresh_seconds: 900,
      providable: IcalProvider.new(ical_url: "https://example.com/family.ics"),
      payload: { "events" => [
        { "uid" => "d", "title" => "Swimming", "all_day" => false,
          "starts_at" => "2026-09-06T14:00:00Z", "ends_at" => "2026-09-06T15:00:00Z",
          "calendar" => "Family" }
      ] }
    )
    @item.sources << second

    body = render_view("today")

    assert_select "span.tag", 2
    assert_select "span.tag", text: @source.tag
    assert_select "span.tag", text: second.tag
    assert_includes body, "Swimming"
  end

  test "a single-calendar tile shows no markers" do
    assert_equal 1, @item.sources.size

    render_view("today")

    assert_select "span.tag", 0
  end

  test "markers show in the agenda layouts too" do
    second = Source.create!(
      name: "Family", refresh_seconds: 900,
      providable: IcalProvider.new(ical_url: "https://example.com/family.ics"),
      payload: { "events" => [
        { "uid" => "d", "title" => "Swimming", "all_day" => false,
          "starts_at" => "2026-09-07T14:00:00Z", "ends_at" => "2026-09-07T15:00:00Z",
          "calendar" => "Family" }
      ] }
    )
    @item.sources << second
    @item.update!(settings: { "day_count" => "5" })

    render_view("next_days")

    assert_select ".agenda span.tag", minimum: 2
  end
end
