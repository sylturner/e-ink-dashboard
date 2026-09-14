require "test_helper"

class RendersControllerTest < ActionDispatch::IntegrationTest
  # Sunday, so the week view's window is the interesting case.
  NOW = ActiveSupport::TimeZone["America/New_York"].parse("2026-09-06 09:00")

  # A WeatherProvider payload, as fetched.
  WEATHER = {
    "units" => "imperial",
    "current" => { "temp" => 72, "feels_like" => 70, "humidity" => 40,
                   "icon" => "day-sunny", "label" => "Clear" },
    "daily" => [
      { "date" => "2026-09-06", "day" => "Sun", "high" => 75, "low" => 60, "precip" => 10,
        "icon" => "day-cloudy", "label" => "Cloudy" },
      { "date" => "2026-09-07", "day" => "Mon", "high" => 78, "low" => 62, "precip" => 0,
        "icon" => "day-sunny", "label" => "Sunny" }
    ],
    "hourly" => [
      { "at" => "2026-09-06T09:00:00-04:00", "temp" => 69, "precip" => 20,
        "icon" => "day-sunny", "label" => "Clear" }
    ],
    "sunrise" => "2026-09-06T06:52:00-04:00",
    "sunset" => "2026-09-06T19:31:00-04:00"
  }.freeze

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
    render_dashboard(@dashboard)
  end

  def render_dashboard(dashboard)
    travel_to(NOW) { get "/render/dashboard", params: { dashboard_id: dashboard.id } }
    assert_response :success
    response.body
  end

  # The weather tile on dashboard one, drawing WEATHER (or another payload).
  def render_weather(view, settings = {}, payload: WEATHER)
    item = dashboard_items(:one)
    sources(:one).update!(payload: payload)
    item.update!(view: view, settings: settings)
    render_dashboard(item.dashboard)
  end

  def merge_a_second_calendar(starts_at:)
    second = Source.create!(
      name: "Family", refresh_seconds: 900,
      providable: IcalProvider.new(ical_url: "https://example.com/family.ics"),
      payload: { "events" => [
        { "uid" => "d", "title" => "Swimming", "all_day" => false,
          "starts_at" => starts_at, "ends_at" => (Time.iso8601(starts_at) + 1.hour).iso8601,
          "calendar" => "Family" }
      ] }
    )
    @item.sources << second
    second
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

  test "month's weekday initials and event dots are parts" do
    @item.update!(settings: { "parts" => { "month" => { "weekday_header" => "0", "event_dots" => "0" } } })
    render_view("month")

    assert_select "div.month-head", 0
    assert_select "span.month-dots", 0
    assert_select "div.month-cell", 35
  end

  # The preview draws the panel it stands in for: the office panel is in
  # New York, and the app is in UTC.
  test "the preview reads the time in the panel's zone" do
    body = render_view("today")

    assert_includes body, "9/6 9:00a"
  end

  test "a panel without a zone reads the app's" do
    devices(:two).update!(time_zone: nil)
    AppSetting.current.update!(time_zone: "America/Los_Angeles")

    body = render_view("today")

    assert_includes body, "9/6 6:00a"
  end

  test "times follow the app's clock" do
    AppSetting.current.update!(clock: "24h")

    body = render_view("today")

    assert_includes body, "9/6 09:00"
  end

  test "month starts its weeks on the app's chosen day" do
    AppSetting.current.update!(week_start: "monday")

    render_view("month")

    assert_equal %w[M T W T F S S], css_select("div.month-head div").map { it.text.strip }
    assert_select "div.month-cell", 35
    assert_select "div.month-cell:first-child span", "31"
    assert_select "div.month-cell--outside", 5
  end

  test "event times can be switched off" do
    @item.update!(settings: { "parts" => { "today" => { "times" => "0" } } })
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
    second = merge_a_second_calendar(starts_at: "2026-09-06T14:00:00Z")

    body = render_view("today")

    assert_select "span.tag", 2
    assert_select "span.tag", text: @source.tag
    assert_select "span.tag", text: second.tag
    assert_includes body, "Swimming"
  end

  test "markers can be switched off on a merged tile" do
    merge_a_second_calendar(starts_at: "2026-09-06T14:00:00Z")
    @item.update!(settings: { "parts" => { "today" => { "tags" => "0" } } })

    body = render_view("today")

    assert_select "span.tag", 0
    assert_includes body, "Swimming"
  end

  test "a single-calendar tile shows no markers" do
    assert_equal 1, @item.sources.size

    render_view("today")

    assert_select "span.tag", 0
  end

  # The render is screenshotted into the device bitmap, so none of the
  # admin layout or its CoreUI assets may reach it.
  test "the render carries none of the admin layout" do
    body = render_view("today")

    assert_no_match(/coreui|importmap|<link[^>]+stylesheet/i, body)
    assert_select "#sidebar", 0
  end

  test "markers show in the agenda layouts too" do
    merge_a_second_calendar(starts_at: "2026-09-07T14:00:00Z")
    @item.update!(settings: { "day_count" => "5" })

    render_view("next_days")

    assert_select ".agenda span.tag", minimum: 2
  end

  test "the clock's date is a part, and its time comes in sizes" do
    clock = @dashboard.dashboard_items.create!(kind: "clock", col: 7, row: 1, col_span: 4, row_span: 2)

    body = render_view("today")
    assert_select ".t-xl", "9:00"
    assert_includes body, "Sunday, September 6"

    clock.update!(settings: { "parts" => { "time" => { "date" => "0" } },
                              "sizes" => { "time" => { "time" => "small" } } })

    body = render_view("today")
    assert_select ".t-xl", 0
    assert_select ".t-md", "9:00"
    assert_not_includes body, "Sunday, September 6"
  end

  test "a headline's feed name is a part, off to start with" do
    sources(:three).update!(payload: { "items" => [ { "title" => "Big news", "source" => "The Paper" } ] })
    news = @dashboard.dashboard_items.create!(kind: "news", view: "headlines", col: 7, row: 3,
                                              col_span: 4, row_span: 3, sources: [ sources(:three) ])

    body = render_view("today")
    assert_includes body, "Big news"
    assert_not_includes body, "The Paper"

    news.update!(settings: { "parts" => { "headlines" => { "source" => "1" } } })

    assert_includes render_view("today"), "The Paper"
  end

  test "weather's default parts draw Right now as before" do
    body = render_weather("current")

    assert_select ".now svg.icon[width=?]", "64"
    assert_select ".now .t-lg", "72°"
    assert_select ".now .t-sm", "Clear"
    assert_select ".now .t-sm", "Feels 70°"
    assert_select ".today > .t-sm", /H 75° · L 60°\s+· 10%/
    assert_not_includes body, "Humidity"
    assert_not_includes body, "Rise"
  end

  test "Right now's parts can be hidden, shown and resized" do
    render_weather("current", {
      "parts" => { "current" => { "icon" => "0", "feels_like" => "0", "humidity" => "1", "sun" => "1" } },
      "sizes" => { "current" => { "temperature" => "small" } }
    })

    assert_select ".now svg", 0
    assert_select ".now .t-md", "72°"
    assert_select ".now .t-sm", text: /Feels/, count: 0
    assert_select ".now .t-sm", "Humidity 40%"
    assert_select ".today > .t-sm", /Rise \d+:52 AM · Set \d+:31 PM/
  end

  test "the chance of rain is labeled when the high and low are hidden" do
    render_weather("current", { "parts" => { "current" => { "high_low" => "0" } } })

    assert_select ".today > .t-sm", "Rain 10%"
  end

  test "a payload without humidity or sun times draws neither, even when shown" do
    payload = WEATHER.merge("current" => WEATHER["current"].except("humidity")).except("sunrise", "sunset")
    body = render_weather("current", { "parts" => { "current" => { "humidity" => "1", "sun" => "1" } } }, payload:)

    assert_not_includes body, "Humidity"
    assert_not_includes body, "Rise"
  end

  # WeatherProvider once stored sunrise and sunset preformatted.
  test "sun times from an older payload are drawn as they were stored" do
    render_weather("current", { "parts" => { "current" => { "sun" => "1" } } },
                   payload: WEATHER.merge("sunrise" => "7:17 AM", "sunset" => "7:42 PM"))

    assert_select ".today > .t-sm", "Rise 7:17 AM · Set 7:42 PM"
  end

  test "the forecast adds the chance of rain and resizes its icons" do
    body = render_weather("forecast")
    assert_select "ul.rows li svg.icon[width=?]", "24", 2
    assert_not_includes body, "10%"

    render_weather("forecast", {
      "parts" => { "forecast" => { "precip" => "1", "condition" => "0" } },
      "sizes" => { "forecast" => { "icon" => "large" } }
    })

    assert_select "ul.rows li svg.icon[width=?]", "32", 2
    assert_select "ul.rows li span.t-sm", "10%"
    assert_select ".sky-label", 0
  end

  test "the hourly strip's parts" do
    render_weather("hourly", { "parts" => { "hourly" => { "temperature" => "0", "precip" => "1" } } })

    assert_select ".hour svg.icon[width=?]", "32"
    assert_select ".hour .sky-label", "Clear"
    assert_select ".hour .t-sm", text: "69°", count: 0
    assert_select ".hour .t-xs", "20%"
  end

  # A note beside the calendar on the office dashboard.
  def render_note(settings = {})
    @dashboard.dashboard_items.create!(kind: "note", col: 7, row: 1, col_span: 6, row_span: 4,
                                       sources: [ sources(:four) ], settings:)
    render_view("today")
  end

  QR_CODE_ON = { "parts" => { "formatted" => { "qr_code" => "1" } } }.freeze

  test "a note tile draws its Markdown, and no QR code to start with" do
    render_note

    assert_select ".note p strong", "Groceries"
    assert_select ".note li input[type=checkbox]", 2
    assert_select ".note li input[type=checkbox][checked]", 1
    assert_select ".note-qr", 0
  end

  test "a note tile's QR code is drawn at the server address, at its size" do
    AppSetting.current.update!(server_url: "http://192.168.1.10:3000")

    render_note(QR_CODE_ON.merge("sizes" => { "formatted" => { "qr_code" => "small" } }))

    url  = "http://192.168.1.10:3000/notes/#{sources(:four).providable_id}/edit"
    edge = (RQRCode::QRCode.new(url, level: :m).modules.size + 8) * 2
    assert_select ".note-tile > .note-qr svg[width=?]", edge.to_s
  end

  test "a note tile draws no QR code until there's a server address" do
    render_note(QR_CODE_ON)

    assert_select ".note p strong", "Groceries"
    assert_select ".note-qr", 0
  end
end
