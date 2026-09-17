require "test_helper"

class FeedTest < ActiveSupport::TestCase
  def feed(name, url: "https://example.com/feed")
    Feed.new(file_fixture("feeds/#{name}").binread, url: url)
  end

  def item(feed, title)
    feed.items.find { it["title"] == title } || flunk("no item titled #{title.inspect}")
  end

  test "reads RSS 2.0 titles, links and dates, newest first" do
    rss = feed("rss2.xml", url: "https://news.example.com/rss")

    assert_equal "Example & News", rss.title
    assert_equal "Enclosure image & entities", rss.items.first["title"]
    assert_equal "https://news.example.com/b", rss.items.first["url"]
    assert_equal "2026-09-16T10:00:00Z", rss.items.first["published_at"]
    assert_equal [ "Example & News" ], rss.items.map { it["source"] }.uniq
  end

  test "finds each kind of RSS item image" do
    rss = feed("rss2.xml", url: "https://news.example.com/rss")

    assert_equal "https://img.example.com/a-460.jpg", item(rss, "Media content, widest wins")["image"]
    assert_equal "https://img.example.com/b.png", item(rss, "Enclosure image & entities")["image"]
    assert_equal "https://img.example.com/d.jpg", item(rss, "Item-level image element")["image"]
  end

  test "skips tracking pixels and resolves relative images against the item's link" do
    rss = feed("rss2.xml", url: "https://news.example.com/rss")

    assert_equal "https://news.example.com/posts/images/c.jpg", item(rss, "Image in the description")["image"]
  end

  test "reads the channel image, but doesn't give it to an item or take a video for a picture" do
    rss = feed("rss2.xml", url: "https://news.example.com/rss")

    assert_equal "https://news.example.com/logo.png", rss.image
    assert_nil item(rss, "No image of its own")["image"]
  end

  test "takes an item's link as its picture when the link is an image" do
    moon = feed("single_image.xml", url: "https://interglacial.com/rss/moon_phase.rss")

    assert_equal "https://interglacial.com/rss/images/moon5.gif", moon.items.first["image"]
  end

  test "reads Atom" do
    atom = feed("atom.xml", url: "https://blog.example.com/feed.atom")

    assert_equal "Atom Example", atom.title
    assert_equal [ "Newer", "An HTML title" ], atom.items.map { it["title"] }
    assert_equal "https://blog.example.com/2026/09/older", atom.items.last["url"]
    assert_equal "https://blog.example.com/pics/older.jpg", atom.items.last["image"]
    assert_equal "https://blog.example.com/newer.jpg", atom.items.first["image"]
    assert_equal "https://blog.example.com/logo.png", atom.image
  end

  test "reads a podcast, never taking the audio for a picture" do
    podcast = feed("podcast.xml")

    assert_equal "https://pod.example.com/art-3000.jpg", podcast.image
    assert_equal "https://pod.example.com/ep2.jpg", item(podcast, "Episode 2")["image"]
    assert_equal "https://pod.example.com/art-3000.jpg", item(podcast, "Episode 1")["image"]
  end

  test "reads RSS 1.0 in its declared encoding past a byte-order mark" do
    rdf = feed("rss1.rdf")

    assert_equal "RDF Example", rdf.title
    assert_equal "Café crème", rdf.items.first["title"]
    assert_equal "https://rdf.example.com/logo.gif", rdf.image
  end

  test "reads JSON Feed, titling an untitled post from its text" do
    json = feed("feed.json")

    assert_equal "JSON Example", json.title
    assert_equal "https://json.example.com/1.jpg", json.items.first["image"]
    assert_equal "A microblog post with no title at all.", json.items.second["title"]
    assert_nil json.items.second["url"]
    assert_nil json.items.second["image"]
    assert_equal "https://json.example.com/icon.png", json.image
  end

  test "keeps an item's summary, author and every element, for headline templates" do
    entry = item(feed("rss2.xml"), "Media content, widest wins")

    assert_equal "A short summary.", entry["summary"]
    assert_equal "Ada Lovelace", entry["author"]
    assert_equal "World, Science", entry.dig("fields", "category")
    assert_equal "Ada Lovelace", entry.dig("fields", "dc:creator")
    assert_equal "460", entry.dig("fields", "media:content@width").split(", ").last
    assert_nil item(feed("rss2.xml"), "No image of its own")["summary"]
  end

  test "keeps a JSON Feed item's fields, looking through its lists" do
    entry = feed("feed.json").items.first

    assert_equal "Grace Hopper", entry["author"]
    assert_equal "The summary.", entry["summary"]
    assert_equal "code, navy", entry.dig("fields", "tags")
  end

  test "reads Atom's default namespace without a prefix" do
    entry = feed("atom.xml").items.last

    assert_equal "urn:1", entry.dig("fields", "id")
    assert_equal "/2026/09/older", entry.dig("fields", "link@href")
  end

  test "decodes every entity, and drops a summary that only repeats the headline" do
    body = <<~XML
      <rss version="2.0"><channel><title>News</title>
        <item><title>Fed hikes rates &#8212; again - Reuters</title><link>https://example.com/fed</link>
          <source url="https://reuters.com">Reuters</source>
          <description>&lt;a href="https://example.com/fed"&gt;Fed hikes rates &amp;mdash; again&lt;/a&gt;&amp;nbsp;&amp;nbsp;&lt;font&gt;Reuters&lt;/font&gt;</description></item>
        <item><title>Caf&#233; opens</title><link>https://example.com/cafe</link>
          <description>&lt;p&gt;Coffee&amp;nbsp;&amp;amp; cake&lt;/p&gt;&lt;script&gt;track()&lt;/script&gt;</description></item>
      </channel></rss>
    XML
    fed, cafe = Feed.new(body, url: "https://example.com/rss").items

    assert_equal "Fed hikes rates — again", fed["title"], "the outlet its <source> names moves to the byline"
    assert_nil fed["summary"]
    assert_equal "Coffee & cake", cafe["summary"]
  end

  test "rejects what isn't a feed" do
    assert_raises(Http::Error) { Feed.new("<html><body>hi</body></html>", url: "https://example.com") }
    assert_raises(Http::Error) { Feed.new("{ not json", url: "https://example.com") }
  end

  test "keeps the given order when some entries are undated" do
    body = <<~XML
      <rss version="2.0"><channel><title>T</title>
        <item><title>Old</title><pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate></item>
        <item><title>Undated</title></item>
      </channel></rss>
    XML

    assert_equal %w[Old Undated], Feed.new(body, url: "https://example.com").items.map { it["title"] }
  end

  test "finds the feed a page advertises" do
    html = file_fixture("feeds/page.html").read

    assert_equal "https://blog.example.com/feed.xml", Feed.discover(html, url: "https://blog.example.com/about")
    assert_nil Feed.discover("<html></html>", url: "https://blog.example.com/")
  end

  test "fetches the advertised feed when given a page" do
    pages = {
      "https://blog.example.com/" => file_fixture("feeds/page.html").read,
      "https://blog.example.com/feed.xml" => file_fixture("feeds/rss2.xml").read
    }
    singleton = Http.singleton_class
    original  = singleton.instance_method(:get)
    singleton.define_method(:get) { |url, **| pages.fetch(url) }

    assert_equal "Example & News", Feed.fetch("https://blog.example.com/").title
  ensure
    singleton.define_method(:get, original)
  end

  test "makes references absolute and drops what a panel can't load" do
    assert_equal "https://a.example/x/y.png", Feed.absolute("y.png", "https://a.example/x/z")
    assert_equal "https://cdn.example/y.png", Feed.absolute("//cdn.example/y.png", "https://a.example/")
    assert_equal "https://a.example/a%20b.png", Feed.absolute("/a b.png", "https://a.example/")
    assert_nil Feed.absolute("data:image/gif;base64,R0lGOD", "https://a.example/")
    assert_nil Feed.absolute("", "https://a.example/")
    assert_nil Feed.absolute("undefined", "https://a.example/")
  end
end
