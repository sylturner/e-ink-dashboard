class RssProvider < ApplicationRecord
  include Providable

  provides label:           "RSS feed",
           icon:            "cil-rss",
           description:     "Headlines and images from an RSS, Atom, JSON or podcast feed.",
           attributes:      %i[feed_url max_items],
           refresh_seconds: 1800

  before_validation :normalize_feed_url
  validates :feed_url, presence: true, format: { with: %r{\Ahttps?://\S+\z} }

  def self.defaults
    { max_items: 10 }
  end

  def detail
    feed_url.to_s.truncate(50)
  end

  # Any feed format works (see Feed), and so does the address of a page
  # that links to its feed.
  def fetch!
    feed = Feed.fetch(feed_url)

    { "title" => feed.title, "image" => feed.image, "items" => feed.items(limit: max_items || 10) }
  end

  private

    # feed:// and feed:https:// are how browsers hand a feed to a reader,
    # and what a copied subscribe link often carries.
    def normalize_feed_url
      self.feed_url = feed_url.to_s.strip.sub(%r{\Afeed:(//)?(?=https?://)}i, "").sub(%r{\Afeed://}i, "https://")
    end
end
