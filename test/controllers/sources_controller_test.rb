require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @source = sources(:one)   # weather, used by dashboard_items(:one)
    @spare  = sources(:three) # rss, not on any dashboard
  end

  test "should get index" do
    get sources_url
    assert_response :success
    assert_select "table.sources tbody tr", Source.count
  end

  test "new without a type offers the type picker" do
    get new_source_url
    assert_response :success
    Source::PROVIDERS.each do |type|
      assert_select "a[href=?]", new_source_path(type: type)
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
    assert_select "input[name=?]", "source[provider][latitude]"
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

  # IcalProvider inherits Providable#fetch!, which raises
  # NotImplementedError -- a ScriptError, not a StandardError.
  test "test reports an unbuilt provider instead of raising" do
    ical = sources(:two)

    post test_source_url(ical)

    assert_redirected_to sources_path
    assert_match(/not built yet/, flash[:alert])
    assert_equal 0, ical.reload.failure_count
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
end
