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

  def news_source(name, items)
    Source.create!(name: name, refresh_seconds: 1800, fetched_at: NOW,
                   providable: RssProvider.new(feed_url: "https://example.com/#{name.parameterize}.xml"),
                   payload: { "items" => items })
  end

  test "a news tile merges its feeds, newest first" do
    item = dashboards(:one).dashboard_items.create!(kind: "news", view: "headlines", col: 5, row: 1,
                                                    col_span: 4, row_span: 4,
                                                    settings: { "event_limit" => "3" })
    item.sources << news_source("World", [
      { "title" => "World newest", "published_at" => "2026-09-06T12:00:00Z", "source" => "World" },
      { "title" => "World oldest", "published_at" => "2026-09-04T12:00:00Z", "source" => "World" }
    ])
    item.sources << news_source("Local", [
      { "title" => "Local middle", "published_at" => "2026-09-05T12:00:00Z", "source" => "Local" }
    ])

    render_dashboard(item.dashboard)

    assert_equal [ "World newest", "Local middle", "World oldest" ],
                 css_select(".feed li .t-clip").map { it.text.strip }
  end

  def render_headlines(template, items)
    item = dashboards(:one).dashboard_items.create!(kind: "news", view: "headlines", col: 5, row: 1,
                                                    col_span: 4, row_span: 4,
                                                    settings: { "template" => template })
    item.sources << news_source("World", items)
    render_dashboard(item.dashboard)
  end

  STORY = {
    "title" => "Big news", "source" => "The Paper", "published_at" => "2026-09-06T11:00:00Z",
    "image" => "https://img.example.com/big.jpg", "fields" => { "dc:creator" => "Ada" }
  }.freeze

  def render_newspaper(settings = {})
    sources(:one).update!(payload: WEATHER)
    paper = dashboards(:one).dashboard_items.create!(kind: "newspaper", col: 5, row: 1, col_span: 4, row_span: 4,
                                                     settings: { "name" => "The Daily Test" }.merge(settings))
    photo = ->(name) { "https://img.example.com/#{name}.jpg" }
    paper.sources << sources(:one)
    paper.sources << news_source("World", [
      { "title" => "World lead", "published_at" => "2026-09-06T12:00:00Z", "image" => photo.("lead"), "summary" => "What the lead is about" },
      { "title" => "World second", "published_at" => "2026-09-06T11:00:00Z", "image" => photo.("second") },
      { "title" => "World brief", "published_at" => "2026-09-06T08:00:00Z", "image" => photo.("brief") },
      { "title" => "World brief 2", "published_at" => "2026-09-06T07:00:00Z", "image" => photo.("brief-2") }
    ])
    paper.sources << news_source("Local", [
      { "title" => "Local big", "published_at" => "2026-09-06T10:00:00Z", "summary" => "A long story" },
      { "title" => "Local brief", "published_at" => "2026-09-06T06:00:00Z", "image" => photo.("local") }
    ])
    yield paper if block_given?
    render_dashboard(paper.dashboard)
  end

  def column_headlines(index)
    css_select(".paper-column")[index].css(".paper-headline").map { it.text.strip }
  end

  test "a newspaper's masthead carries the weather, the edition and the date" do
    render_newspaper

    assert_select ".card--newspaper .paper-masthead" do
      assert_select ".paper-name.hl-jacquard12-63[data-sizes=?]", "jacquard12-63 jacquard24-43 jacquard12-42 jacquard12-21", "The Daily Test"
      assert_select ".paper-weather .paper-temp", "72°"
      assert_select ".paper-ear .paper-small", "H 75° · L 60°"
      assert_select ".paper-ear--right .paper-small", "6:00 AM edition" # the panel is in Los Angeles
    end
    assert_select ".paper-dateline", /Sunday, September 6, 2026\s+All the news that fits/
    assert_select ".paper script", /document\.fonts\.ready/
  end

  test "a newspaper leads with its newest photo, and varies the stories around it" do
    render_newspaper

    assert_select ".paper-lead .paper-story--fill" do
      assert_select ".paper-headline.hl-jersey15-54[data-sizes=?]", "jersey15-54 jersey25-41 jersey20-34 jersey15-27", "World lead"
      assert_select "img.paper-photo[src=?]", "https://img.example.com/lead.jpg"
      assert_select ".paper-byline", "World · 1h"
      assert_select ".paper-summary.t-clip-3", "What the lead is about"
    end

    # The left column opens with the next photo, the right with a big
    # headline from another source; briefs follow, the sources taking turns.
    assert_equal [ "World second", "World brief", "World brief 2" ], column_headlines(0)
    assert_equal [ "Local big", "Local brief" ], column_headlines(1)
    assert_select ".paper-column .paper-story--top img.paper-photo[src=?]", "https://img.example.com/second.jpg"
    assert_select ".paper-column .paper-headline.hl-jersey25-41", "Local big"
    assert_select ".paper-column img.paper-thumb", 2 # some briefs, not all
    assert_select ".paper-column .paper-summary.t-clip-6", "A long story"
    assert_select ".paper-headline.t-clip", 0, "a headline is never clipped"
  end

  test "a newspaper lists its calendars' events under way or starting in the next hours" do
    # Dashboard one's panel is in Los Angeles, where it's 6:00 AM Sunday.
    render_newspaper("event_hours" => "36") do |paper|
      paper.sources << sources(:two)
      paper.sources << Source.create!(name: "Family", refresh_seconds: 1800, providable: IcalProvider.new(ical_url: "https://example.com/family.ics"),
                                      payload: { "events" => [
                                        { "title" => "Brunch", "starts_at" => "2026-09-06T15:00:00Z", "ends_at" => "2026-09-06T16:00:00Z" },
                                        { "title" => "Too far off", "starts_at" => "2026-09-08T12:00:00Z", "ends_at" => "2026-09-08T13:00:00Z" }
                                      ] })
    end

    assert_select ".paper-column .paper-events" do
      assert_select ".paper-events-title", "Upcoming events"
      whens  = css_select(".paper-event .paper-byline").map { it.text.strip }
      titles = css_select(".paper-event-title").map { it.text.squish }
      assert_equal [ "Today · Now", "Today · 8:00 AM", "Tomorrow · All day" ], whens
      assert_equal [ "WOR Standup", "FAM Brunch", "WOR Labor Day" ], titles
    end
  end

  test "a newspaper embeds only the fonts its style uses, and draws in its own" do
    render_newspaper

    assert_select ".paper--broadsheet style", /np-jacquard12/
    assert_select ".paper--broadsheet style", text: /np-home_video/, count: 0
    assert_select ".paper--caps, .paper-kicker, .paper-flag", 0
  end

  test "a tabloid runs its lead across two columns, under a kicker, in capitals" do
    render_newspaper { |paper| paper.update!(view: "tabloid") }

    assert_select ".paper--tabloid.paper--caps .paper-page--tabloid" do
      assert_select "> .paper-lead .paper-kicker", "Exclusive!"
      assert_select "> .paper-lead .paper-headline.hl-jersey25-82", "World lead"
      assert_select "> .paper-column", 1
    end
    assert_select ".paper-dateline", /Shocking but true!/
    assert_select ".paper--tabloid style", text: /np-jacquard/, count: 0
  end

  test "a zine cuts its name out of mixed letters, in fonts the page already has" do
    render_newspaper("name" => "Zine") { |paper| paper.update!(view: "zine") }

    assert_select ".paper--zine .paper-name.hl-ransom-lg" do
      assert_equal "Zine", css_select(".ransom").map(&:text).join
      assert_select ".ransom--inverted, .ransom--boxed, .ransom--plain", 4
    end
    assert_select ".paper--zine style", text: /np-press_start/, count: 0
    assert_select ".paper--zine style", /\.hl-ransom-lg \.ransom-2 \{ font: 400 40px\/42px "PressStart2P"/
  end

  test "a patriotic paper flies a flag of pixel stars" do
    render_newspaper { |paper| paper.update!(view: "patriot") }

    assert_select ".paper--patriot .paper-flag .paper-canton svg.pixel-art--star", 4
    assert_select ".paper-kicker", "Breaking news"
    assert_select ".paper-events-title", 0 # no calendar
  end

  test "a wizarding gazette stretches its name and lead, and sets them at half size to fit" do
    render_newspaper { |paper| paper.update!(view: "wizard") }

    assert_select ".paper--wizard" do
      assert_select ".paper-name.hl-jacquarda_bastarda-26[data-sizes=?]", "jacquarda_bastarda-26 jacquarda_bastarda-13"
      assert_select ".paper-flourish svg.pixel-art--sparkle", 3
      assert_select ".paper-lead .paper-kicker", "Special edition"
      assert_select ".paper-lead .paper-headline[data-sizes=?]", "jacquard24-43 jacquard12-42 jacquard12-21"
    end
    assert_select ".paper-dateline", /Mischief, marvels and the morning news/
    assert_select ".paper-page > .paper-strip", /\AMischief, marvels and the morning news \* /
    assert_select ".paper-column .paper-headline .shift-word .shift.shift-wave-0", minimum: 1
    assert_select ".paper-lead .paper-headline .shift", 0, "the lead is stretched, not waved"
  end

  test "a 90s hacker paper glitches its headlines and spells its motto in binary" do
    render_newspaper("motto" => "Hi") { |paper| paper.update!(view: "hacker") }

    assert_select ".paper--hacker" do
      assert_select ".paper-page > .paper-strip.paper-strip--binary", /\A01001000 01101001 \* /
      assert_select ".paper-column .paper-headline .shift.shift-glitch-3", minimum: 1
      assert_select ".paper-lead .paper-kicker", "Access granted"
      assert_select "style", /\.shift-glitch-3 \{ transform: translate\(3px, 0px\); \}/
      css_select(".paper-column .paper-headline").each do |headline|
        assert_equal [ headline.css(".shift").first ], headline.css(".shift--inverted").to_a, "only the first letter is inverted"
      end
    end
  end

  test "a custom paper takes its fonts and arrangement from its settings" do
    render_newspaper("layout" => "tabloid", "caps" => "1", "headline_font" => "press_start",
                     "masthead_font" => "ransom", "text_font" => "Kernel") { |paper| paper.update!(view: "custom") }

    assert_select ".paper--custom.paper--caps .paper-page--tabloid"
    assert_select ".paper-name.hl-ransom-lg .ransom", 12
    assert_select ".paper-lead .paper-headline.hl-press_start-56"
    assert_select ".paper--custom style", /#paper-\d+ \{ font: 400 12px\/14px "np-pixantiqua"/ # an unknown font falls back
    assert_select ".paper-kicker", 0
  end

  test "a newspaper's parts can each be hidden" do
    render_newspaper("parts" => { "broadsheet" => { "weather" => "0", "dateline" => "0", "photos" => "0", "events" => "0",
                                                    "bylines" => "0", "summaries" => "0" } }) do |paper|
      paper.sources << sources(:two)
    end

    assert_select ".paper-name", "The Daily Test"
    assert_select ".paper-weather, .paper-dateline, .paper-byline, .paper-summary, .paper-thumb, .paper-story--top, .paper-events", 0
    assert_select ".paper-lead img.paper-photo", 1, "the lead keeps its photo"
  end

  test "a news tile draws the title alone, with no picture, to start with" do
    body = render_headlines(nil, [ STORY ])

    assert_select ".headlines--none li > .headline-text > div", 1
    assert_select ".headline-text .t-clip.t-clip-2", "Big news"
    assert_select ".headline-image", 0
    assert_not_includes body, "The Paper"
  end

  test "a headline template maps an item's fields to its picture and lines" do
    render_headlines({
      "image" => { "placement" => "left", "size" => "medium" },
      "lines" => [
        { "field" => "title", "size" => "large", "clamp" => "3" },
        { "field" => "custom", "format" => "{dc:creator} · {source} · {age} · {date}", "size" => "small", "clamp" => "1" },
        { "field" => "author", "size" => "small", "clamp" => "1" }
      ]
    }, [ STORY ])

    assert_select ".headlines--left li" do
      assert_select "img.headline-image[src=?][width='80'][height='80']", "https://img.example.com/big.jpg"
      assert_select ".headline-text > div", 2 # the author is empty
      assert_select ".headline-text > .t-md.t-clip-3", "Big news"
      assert_select ".headline-text > .t-xs.t-clip-1", "Ada · The Paper · 2h · Sep 6"
    end
  end

  def post_preview(params)
    travel_to(NOW) { post render_preview_path, params: { dashboard_id: @dashboard.id }.merge(params) }
    response.body
  end

  def saved_state
    [ @item.reload.attributes, @dashboard.reload.attributes, DashboardItemSource.count ]
  end

  test "the preview draws a tile's unsaved changes, and saves none of them" do
    second = merge_a_second_calendar(starts_at: "2026-09-06T14:00:00Z")

    assert_no_changes -> { saved_state } do
      post_preview item_id: @item.id, dashboard_item: {
        view: "today", title: "Draft header", source_ids: [ "", @source.id.to_s ],
        settings: { parts: { today: { times: "0" } } }
      }
    end

    assert_response :success
    assert_select ".card-header", "Draft header"
    assert_includes response.body, "Standup"
    assert_not_includes response.body, "9:00"
    assert_not_includes response.body, second.name
    assert_select "span.tag", 0
  end

  test "the preview keeps a tile's sources when the form sends none" do
    body = post_preview item_id: @item.id, dashboard_item: { view: "today" }

    assert_response :success
    assert_includes body, "Standup"
  end

  test "the preview draws the dashboard's unsaved settings" do
    assert_no_changes -> { saved_state } do
      post_preview dashboard: { name: @dashboard.name, theme: "night", grid_columns: "6", grid_rows: "4" },
                   item_id: @item.id, dashboard_item: { view: "week" }
    end

    assert_response :success
    assert_select "html[data-theme=?]", "night"
    assert_match(/--grid-cols: 6;/, response.body)
  end

  test "the preview leaves out a tile unchecked from the dashboard" do
    post_preview item_id: @item.id, dashboard_item: { visible: "0" }

    assert_response :success
    assert_select ".card", 0
  end

  test "the preview says why changes that can't be saved aren't drawn" do
    post_preview dashboard: { name: "", theme: "default", grid_columns: "12", grid_rows: "6" },
                 item_id: @item.id, dashboard_item: { view: "forecast" }

    assert_response :unprocessable_content
    assert_select ".card-header", "These changes can't be saved"
    assert_select "li", "Name can't be blank"
    assert_select "li", /View isn't available/
  end

  test "the preview only takes a tile from the dashboard it draws" do
    post_preview item_id: dashboard_items(:one).id, dashboard_item: { title: "Elsewhere" }

    assert_response :not_found
  end
end
