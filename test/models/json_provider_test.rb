require "test_helper"

class JsonProviderTest < ActiveSupport::TestCase
  test "fetch! keeps the parsed reply under data" do
    provider = JsonProvider.new(url: "https://api.example.com/state")

    payload = stub_method(Http, :get, returns: '{"state":"on","list":[1,2]}') { provider.fetch! }

    assert_equal({ "data" => { "state" => "on", "list" => [ 1, 2 ] } }, payload)
  end

  test "fetch! sends its headers, asking for JSON" do
    provider = JsonProvider.new(url: "https://ha.example.com/api/states/sun.sun",
                                headers: "Authorization: Bearer abc:def\n\nX-Key:  1 ")
    sent = nil
    original = Http.method(:get)
    Http.define_singleton_method(:get) { |_url, headers:| sent = headers; "[]" }
    provider.fetch!

    assert_equal({ "Accept" => "application/json", "Authorization" => "Bearer abc:def", "X-Key" => "1" }, sent)
  ensure
    Http.define_singleton_method(:get, original)
  end

  test "fetch! raises Http::Error for a reply that isn't JSON, or is too large" do
    provider = JsonProvider.new(url: "https://example.com/")

    stub_method(Http, :get, returns: "<html></html>") do
      assert_raises(Http::Error, match: /isn't JSON/) { provider.fetch! }
    end

    stub_method(Http, :get, returns: "1" * (JsonProvider::MAX_BYTES + 1)) do
      assert_raises(Http::Error, match: /larger than/) { provider.fetch! }
    end
  end

  test "needs a web address, and headers written as Name: value" do
    assert JsonProvider.new(url: " https://example.com/x ").tap(&:validate).then { it.errors.empty? && it.url == "https://example.com/x" }
    assert_not JsonProvider.new(url: "ftp://example.com/").valid?

    provider = JsonProvider.new(url: "https://example.com/", headers: "Authorization Bearer abc")
    assert_not provider.valid?
    assert_match "Authorization Bearer abc", provider.errors[:headers].first
  end
end
