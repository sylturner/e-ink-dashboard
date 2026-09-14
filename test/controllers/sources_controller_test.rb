require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @source = sources(:one)   # weather, used by dashboard_items(:one)
    @spare  = sources(:three) # rss, not on any dashboard
  end

  test "the index lists every source with its health and actions" do
    @spare.update!(failure_count: 2, last_error: "503 from example.com")

    get sources_url

    assert_response :success
    assert_select "header.page-hero a[href=?]", new_source_path
    assert_select "table.table.sources tbody tr", Source.count
    assert_select "table.sources .badge", "OK"
    assert_select "table.sources .badge", "2 failures"
    assert_select "table.sources .text-app-danger", "503 from example.com"
    assert_select "table.sources form[action=?] button", test_source_path(@spare), "Test #{@spare.name}"
    assert_select "table.sources form[action=?] button", source_path(@spare), "Delete #{@spare.name}"
  end

  test "with no sources the index offers to add one" do
    Source.destroy_all

    get sources_url

    assert_select "table.sources", 0
    assert_select "main a[href=?]", new_source_path, 2
  end

  test "new without a type offers the type picker" do
    get new_source_url
    assert_response :success
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", sources_path
    Source::PROVIDERS.each do |type|
      provider = Source.provider_class(type)
      assert_select "ul.type-list a.stretched-link[href=?]", new_source_path(type: type), provider.label
      assert_select "ul.type-list li", text: /#{Regexp.escape(provider.description)}/
    end
  end

  test "new with an unknown type falls back to the picker" do
    get new_source_url(type: "Object")
    assert_response :success
    assert_select "ul.type-list"
  end

  test "new with a type renders that provider's fields" do
    get new_source_url(type: "RssProvider")
    assert_response :success
    assert_select "input[name=?]", "source[provider][feed_url]"
    assert_select "input[name=?][value=?]", "source[refresh_seconds]", "1800"
  end

  test "hints are tied to the fields they describe" do
    get new_source_url(type: "RssProvider")

    assert_select "input[name=?][aria-describedby=?]", "source[provider][feed_url]", "source_provider_feed_url_hint"
    assert_select ".form-text#source_provider_feed_url_hint"
    assert_select "input[name=?][aria-describedby=?]", "source[refresh_seconds]", "source_refresh_seconds_hint"
  end

  # WCAG 1.3.1 and 4.1.3: the lookup box is labeled, and what it finds is
  # announced.
  test "the weather form's place lookup is labeled and announces its results" do
    get new_source_url(type: "WeatherProvider")

    assert_select "[data-controller=geocode][data-geocode-url-value=?]", geocode_sources_path
    assert_select "label[for=geocode_query]", "Find a place"
    assert_select "input#geocode_query[aria-describedby=geocode_status]:not([name])"
    assert_select "#geocode_status[role=status]"
  end

  test "creates a source and its provider together" do
    assert_difference [ "Source.count", "RssProvider.count" ], 1 do
      post sources_url(type: "RssProvider"), params: {
        source: { name: "Example feed", refresh_seconds: 900,
                  provider: { feed_url: "https://example.com/rss", max_items: 5 } }
      }
    end

    assert_redirected_to sources_path
    source = Source.order(:id).last
    assert_equal "RssProvider", source.providable_type
    assert_equal "https://example.com/rss", source.providable.feed_url
    assert_equal 5, source.providable.max_items
  end

  test "an invalid provider re-renders the form instead of blowing up" do
    assert_no_difference [ "Source.count", "RssProvider.count" ] do
      post sources_url(type: "RssProvider"), params: {
        source: { name: "Broken", refresh_seconds: 900,
                  provider: { feed_url: "not a url" } }
      }
    end

    assert_response :unprocessable_content
    assert_select "ul.errors li", /Feed url is invalid/
    assert_select "input.is-invalid[name=?] ~ .invalid-feedback", "source[provider][feed_url]", /Feed url is invalid/
  end

  test "an invalid source re-renders the form" do
    assert_no_difference [ "Source.count", "RssProvider.count" ] do
      post sources_url(type: "RssProvider"), params: {
        source: { name: "", refresh_seconds: 900,
                  provider: { feed_url: "https://example.com/rss" } }
      }
    end

    assert_response :unprocessable_content
    assert_select "ul.errors li", /Name can't be blank/
    assert_select "input.is-invalid[name=?]", "source[name]"
  end

  test "refuses an unknown provider type" do
    assert_no_difference "Source.count" do
      post sources_url(type: "Kernel"), params: { source: { name: "X" } }
    end

    assert_redirected_to new_source_path
    assert_equal "Unknown source type", flash[:alert]
  end

  test "should get edit" do
    get edit_source_url(@source)
    assert_response :success
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", sources_path
    assert_select "h1", @source.name
    assert_select "input[name=?]", "source[provider][latitude]"
  end

  test "show summarizes the source and its last payload" do
    @source.update!(payload: { "current" => { "temp" => 71 } })

    get source_url(@source)

    assert_response :success
    assert_select "h1", @source.name
    assert_select "dd", "15 minutes"
    assert_select "pre.source-payload", /"temp": 71/
  end

  test "updates the source and the provider" do
    patch source_url(@source), params: {
      source: { name: "Renamed", refresh_seconds: 600,
                provider: { latitude: 33.81, longitude: -84.24,
                            units: "metric", time_zone: "America/New_York" } }
    }

    assert_redirected_to sources_path
    @source.reload
    assert_equal "Renamed", @source.name
    assert_equal 600, @source.refresh_seconds
    assert_equal "metric", @source.providable.units
    assert_in_delta 33.81, @source.providable.latitude.to_f, 0.001
  end

  test "an invalid update shows the provider's error and changes nothing" do
    patch source_url(@source), params: {
      source: { name: "Renamed", refresh_seconds: 600,
                provider: { latitude: "", longitude: -84.24, units: "imperial" } }
    }

    assert_response :unprocessable_content
    assert_select "ul.errors li", /Latitude can't be blank/
    assert_select "input.is-invalid[name=?]", "source[provider][latitude]"
    assert_select "h1", "Home weather"
    assert_equal "Home weather", @source.reload.name
  end

  test "refuses to destroy a source that is on a dashboard" do
    assert_no_difference "Source.count" do
      delete source_url(@source)
    end

    assert_redirected_to sources_path
    assert_match(/Still used by/, flash[:alert])
    assert_match(/Weather/, flash[:alert])
  end

  test "destroys an unused source and its provider" do
    assert_difference [ "Source.count", "RssProvider.count" ], -1 do
      delete source_url(@spare)
    end

    assert_redirected_to sources_path
  end

  # Stubs the HTTP layer rather than fetch!, so the provider's own
  # parsing and normalizing still run.
  FEED = <<~XML
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
      <title>Example wire</title>
      <item>
        <title>Headline one</title>
        <link>https://example.com/1</link>
        <pubDate>Mon, 01 Sep 2025 12:00:00 GMT</pubDate>
      </item>
      <item>
        <title>Headline two</title>
        <link>https://example.com/2</link>
        <pubDate>Mon, 01 Sep 2025 11:00:00 GMT</pubDate>
      </item>
    </channel></rss>
  XML

  test "test fetches and reports what came back" do
    stub_method(Http, :get, returns: FEED) do
      post test_source_url(@spare)
    end

    assert_redirected_to sources_path
    assert_match(/2 items, newest: Headline one/, flash[:notice])

    @spare.reload
    assert_equal 2, @spare.payload["items"].size
    assert_equal "Headline one", @spare.payload.dig("items", 0, "title")
    assert_not_nil @spare.fetched_at
    assert_equal 0, @spare.failure_count
  end

  test "test records the failure when the fetch blows up" do
    stub_method(Http, :get, raises: Http::Error.new("503 from example.com")) do
      post test_source_url(@spare)
    end

    assert_redirected_to sources_path
    assert_match(/503 from example.com/, flash[:alert])

    @spare.reload
    assert_equal 1, @spare.failure_count
    assert_equal "503 from example.com", @spare.last_error
    assert_nil @spare.fetched_at
  end

  ICS = <<~ICS
    BEGIN:VCALENDAR
    VERSION:2.0
    X-WR-CALNAME:Work
    BEGIN:VEVENT
    UID:a
    DTSTAMP:20260901T120000Z
    DTSTART:20260907T140000Z
    DTEND:20260907T150000Z
    SUMMARY:Standup
    END:VEVENT
    END:VCALENDAR
  ICS

  test "test fetches a calendar and reports the event count" do
    ical = sources(:two)

    travel_to Time.utc(2026, 9, 5, 12) do
      stub_method(Http, :get, returns: ICS) do
        post test_source_url(ical)
      end
    end

    assert_redirected_to sources_path
    assert_match(/1 events/, flash[:notice])
    assert_equal 1, ical.reload.payload["events"].size
  end

  test "new calendar form offers a file upload field" do
    get new_source_url(type: "IcalProvider")

    assert_response :success
    assert_select "form[enctype=?]", "multipart/form-data"
    assert_select "input[type=file][name=?]", "source[provider][ics_file]"
  end

  test "a calendar with an uploaded file offers to remove it" do
    ical = sources(:two)
    ical.providable.update!(ics_data: "BEGIN:VCALENDAR", ics_filename: "team.ics")

    get edit_source_url(ical)

    assert_select ".form-text", /On file: team\.ics/
    assert_select ".form-check input[type=checkbox][name=?]", "source[provider][remove_ics]"
    assert_select "label.form-check-label[for=?]", "source_provider_remove_ics"
  end

  test "creates a calendar source from an uploaded .ics file" do
    file = fixture_file_upload("calendar.ics", "text/calendar")

    assert_difference [ "Source.count", "IcalProvider.count" ], 1 do
      post sources_url(type: "IcalProvider"), params: {
        source: { name: "Team calendar", refresh_seconds: 900,
                  provider: { ics_file: file, include_all_day: "1" } }
      }
    end

    assert_redirected_to sources_path
    provider = Source.order(:id).last.providable
    assert_equal "calendar.ics", provider.ics_filename
    assert_match(/BEGIN:VCALENDAR/, provider.ics_data)

    travel_to Time.utc(2026, 9, 5, 12) do
      assert_operator provider.fetch!["events"].size, :>, 0
    end
  end

  test "a calendar source with neither url nor file re-renders the form" do
    assert_no_difference "Source.count" do
      post sources_url(type: "IcalProvider"), params: {
        source: { name: "Empty", refresh_seconds: 900, provider: { ical_url: "" } }
      }
    end

    assert_response :unprocessable_content
    assert_select "ul.errors li", /upload an \.ics file/
  end

  test "uploading a replacement .ics file on edit swaps the calendar" do
    ical = sources(:two)
    ical.providable.update!(ics_data: "OLD", ics_filename: "old.ics")

    patch source_url(ical), params: {
      source: { name: ical.name, refresh_seconds: ical.refresh_seconds,
                provider: { ics_file: fixture_file_upload("calendar.ics", "text/calendar") } }
    }

    assert_redirected_to sources_path
    assert_equal "calendar.ics", ical.reload.providable.ics_filename
    assert_match(/BEGIN:VCALENDAR/, ical.providable.ics_data)
  end

  # Providable#fetch! raises NotImplementedError, which descends from
  # ScriptError rather than StandardError -- so `rescue StandardError`
  # alone would turn a provider without a fetch! into a 500.
  test "NotImplementedError is not a StandardError" do
    assert_not NotImplementedError.ancestors.include?(StandardError)
    assert_includes NotImplementedError.ancestors, ScriptError
  end

  test "geocode returns normalized places" do
    places = [ { "label" => "Clarkston, Georgia, US", "latitude" => 33.8,
                 "longitude" => -84.2, "time_zone" => "America/New_York" } ]

    stub_method(Geocoding, :search, returns: places) do
      get geocode_sources_url(q: "Clarkston")
    end

    assert_response :success
    assert_equal places, JSON.parse(response.body)["results"]
  end

  test "geocode reports an upstream failure" do
    stub_method(Geocoding, :search, raises: Http::Error.new("timed out")) do
      get geocode_sources_url(q: "Clarkston")
    end

    assert_response :bad_gateway
    body = JSON.parse(response.body)
    assert_empty body["results"]
    assert_equal "timed out", body["error"]
  end

  test "a note's form takes its body and offers no refresh interval" do
    get new_source_url(type: "NoteProvider")

    assert_response :success
    assert_select "textarea[name=?][aria-describedby=?]", "source[provider][body]", "source_provider_body_hint"
    assert_select "input[type=hidden][name=?][value=?]", "source[refresh_seconds]", 1.day.to_i.to_s
    assert_select "input[type=number][name=?]", "source[refresh_seconds]", 0
    assert_select "#note_phone_link", 0, "an unsaved note has no phone page yet"
  end

  test "creates a note" do
    assert_difference [ "Source.count", "NoteProvider.count" ], 1 do
      post sources_url(type: "NoteProvider"), params: {
        source: { name: "Hall note", refresh_seconds: 1.day.to_i, provider: { body: "- [ ] keys" } }
      }
    end

    assert_redirected_to sources_path
    source = Source.order(:id).last
    assert_equal "- [ ] keys", source.providable.body
    assert_equal 1.day.to_i, source.refresh_seconds
    assert_equal({ "body" => "- [ ] keys" }, source.payload, "a new note draws without waiting on a job")
  end

  test "a note's edit page links to its phone page" do
    note = sources(:four)

    get edit_source_url(note)

    assert_select "input#note_phone_link[readonly][value=?]:not([name])", edit_note_url(note.providable)
    assert_select "a[href=?]", edit_note_url(note.providable), "Open phone page"
    assert_select "#note_phone_link_hint a[href=?]", edit_settings_path
  end

  test "with a server address, a note's phone link uses it" do
    AppSetting.current.update!(server_url: "http://192.168.1.10:3000")
    note = sources(:four)

    get edit_source_url(note)

    assert_select "input#note_phone_link[value=?]", "http://192.168.1.10:3000/notes/#{note.providable_id}/edit"
    assert_select "#note_phone_link_hint a", 0
  end

  test "a note has nothing to test or refresh on a schedule" do
    note = sources(:four)

    get sources_url
    assert_select "table.sources form[action=?]", test_source_path(note), 0
    assert_select "table.sources form[action=?]", source_path(note)

    get source_url(note)
    assert_select "dt", text: "Refreshes every", count: 0
  end
end
