require "test_helper"

class RssProviderTest < ActiveSupport::TestCase
  test "fetch! keeps the newest max_items" do
    provider = RssProvider.new(feed_url: "https://news.example.com/rss", max_items: 2)

    payload = stub_method(Http, :get, returns: file_fixture("feeds/rss2.xml").binread) do
      provider.fetch!
    end

    assert_equal [ "Enclosure image & entities", "Media content, widest wins" ],
                 payload["items"].map { it["title"] }
  end

  test "fetch! raises Http::Error for a response that isn't a feed" do
    provider = RssProvider.new(feed_url: "https://example.com/")

    stub_method(Http, :get, returns: "<html><body>no feed here</body></html>") do
      assert_raises(Http::Error) { provider.fetch! }
    end
  end

  test "accepts feed: links as the https address they stand for" do
    assert_equal "https://example.com/rss", RssProvider.new(feed_url: "feed://example.com/rss").tap(&:validate).feed_url
    assert_equal "http://example.com/rss", RssProvider.new(feed_url: "feed:http://example.com/rss").tap(&:validate).feed_url
    assert_equal "https://example.com/rss", RssProvider.new(feed_url: " https://example.com/rss ").tap(&:validate).feed_url
  end
end
