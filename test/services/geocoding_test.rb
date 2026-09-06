require "test_helper"

class GeocodingTest < ActiveSupport::TestCase
  RESPONSE = {
    "results" => [
      { "name" => "Clarkston", "admin1" => "Georgia", "country_code" => "US",
        "latitude" => 33.8095, "longitude" => -84.2399,
        "timezone" => "America/New_York" },
      { "name" => "Clarkston", "admin1" => nil, "country_code" => "GB",
        "latitude" => 55.7833, "longitude" => -4.3, "timezone" => "Europe/London" }
    ]
  }.freeze

  test "returns nothing for a blank query without calling out" do
    stub_method(Http, :get_json, raises: Http::Error.new("should not be called")) do
      assert_equal [], Geocoding.search("")
      assert_equal [], Geocoding.search(nil)
    end
  end

  test "normalizes each result to label, coordinates and zone" do
    places = stub_method(Http, :get_json, returns: RESPONSE) do
      Geocoding.search("Clarkston")
    end

    assert_equal 2, places.size
    assert_equal "Clarkston, Georgia, US", places.first["label"]
    assert_in_delta 33.8095, places.first["latitude"], 0.0001
    assert_equal "America/New_York", places.first["time_zone"]
  end

  test "skips a missing region rather than leaving a gap in the label" do
    places = stub_method(Http, :get_json, returns: RESPONSE) do
      Geocoding.search("Clarkston")
    end

    assert_equal "Clarkston, GB", places.second["label"]
  end

  test "returns nothing when the endpoint sends no results" do
    places = stub_method(Http, :get_json, returns: {}) do
      Geocoding.search("Nowheresville")
    end

    assert_equal [], places
  end
end
