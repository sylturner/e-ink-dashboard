class RssProvider < ApplicationRecord
  include Providable

  provides label:           "RSS feed",
           attributes:      %i[feed_url max_items],
           refresh_seconds: 1800

  validates :feed_url, presence: true, format: { with: %r{\Ahttps?://\S+\z} }

  def self.defaults
    { max_items: 10 }
  end

  def detail
    feed_url.to_s.truncate(50)
  end

  def fetch!
    feed = Feedjira.parse(Http.get(feed_url))
    raise Http::Error, "could not parse feed" if feed.nil?

    items = feed.entries.first(max_items || 10).map do |entry|
      {
        "title"        => clean(entry.title),
        "url"          => entry.url,
        "published_at" => entry.published&.iso8601,
        "source"       => feed.title
      }
    end

    { "items" => items }
  end

  private

  # Feed titles carry entities and stray markup often enough to matter,
  # and a stray tag renders as literal text on the panel.
  def clean(text)
    return "" if text.blank?

    ActionView::Base.full_sanitizer.sanitize(text)
                    .then { |s| CGI.unescapeHTML(s.to_s) }
                    .gsub(/\s+/, " ")
                    .strip
  end
end
