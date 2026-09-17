require "test_helper"

class NewsFeedTest < ActiveSupport::TestCase
  setup do
    @item = dashboards(:one).dashboard_items.create!(kind: "news", col: 1, row: 1, col_span: 1, row_span: 1)
  end

  def attach(name, items, fetched_at: Time.utc(2026, 9, 16, 12))
    provider = RssProvider.create!(feed_url: "https://example.com/#{name.parameterize}.xml")
    source = Source.create!(name: name, providable: provider, refresh_seconds: 1800,
                            fetched_at: fetched_at, payload: { "items" => items })
    @item.sources << source
    source
  end

  def story(title, published_at, url: "https://example.com/#{title.parameterize}")
    { "title" => title, "url" => url, "published_at" => published_at }
  end

  test "merges every attached feed, newest first" do
    attach("A", [ story("A new", "2026-09-16T10:00:00Z"), story("A old", "2026-09-14T10:00:00Z") ])
    attach("B", [ story("B middle", "2026-09-15T10:00:00Z") ])

    assert_equal [ "A new", "B middle", "A old" ], NewsFeed.for(@item.reload).map { it["title"] }
  end

  test "dates an undated item by its source's last fetch" do
    attach("News", [ story("Morning", "2026-09-16T08:00:00Z"), story("Yesterday", "2026-09-15T08:00:00Z") ])
    attach("Moon", [ story("A waxing moon", nil) ], fetched_at: Time.utc(2026, 9, 16, 9))

    assert_equal [ "A waxing moon", "Morning", "Yesterday" ], NewsFeed.for(@item.reload).map { it["title"] }
  end

  test "keeps a feed's own order among items it doesn't date" do
    attach("Undated", [ story("First", nil), story("Second", nil), story("Third", nil) ])

    assert_equal %w[First Second Third], NewsFeed.for(@item.reload).map { it["title"] }
  end

  test "shows a story two feeds carry once" do
    attach("Front page", [ story("Big story", "2026-09-16T10:00:00Z", url: "https://example.com/big") ])
    attach("Topic", [ story("Big story (topic)", "2026-09-16T09:00:00Z", url: "https://example.com/big") ])

    assert_equal [ "Big story" ], NewsFeed.for(@item.reload).map { it["title"] }
  end

  test "has nothing for a tile whose feeds haven't been fetched" do
    attach("Empty", nil, fetched_at: nil)

    assert_equal [], NewsFeed.for(@item.reload)
  end

  test "each entry carries the name its source was given" do
    attach("World desk", [ story("Big story", "2026-09-16T10:00:00Z").merge("source" => "Example News - World") ])

    assert_equal [ "World desk" ], NewsFeed.for(@item.reload).map { it["source_name"] }
  end

  test "by_turns lets each source take a turn, newest first" do
    attach("Busy", (1..3).map { story("Busy #{it}", "2026-09-16T1#{4 - it}:00:00Z") })
    attach("Quiet", [ story("Quiet 1", "2026-09-15T10:00:00Z") ])

    assert_equal [ "Busy 1", "Quiet 1", "Busy 2", "Busy 3" ],
                 NewsFeed.by_turns(NewsFeed.for(@item.reload)).map { it["title"] }
    assert_equal [], NewsFeed.by_turns([])
  end
end
