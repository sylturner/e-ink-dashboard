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
    feed = Feedjira.parse(Http.get(feed_url), parser: Feedjira::Parser::RSS)
    raise Http::Error, "could not parse feed" if feed.nil?

    items = feed.entries.first(max_items || 10).map do |entry|
      {
        "title"        => clean(entry.title),
        "url"          => entry.url,
        "published_at" => entry.published&.iso8601,
        "image"        => extract_image_from_entry(entry),
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

  def extract_image_from_entry(entry)
    # 1. Feedjira native media attributes (<media:content>, <media:thumbnail>)
    return entry.image if entry.respond_to?(:image) && entry.image
    return entry.media_url if entry.respond_to?(:media_url) && entry.media_url
    return entry.thumbnail_url if entry.respond_to?(:thumbnail_url) && entry.thumbnail_url

    # 2. RSS <enclosure>
    if entry.respond_to?(:enclosure_url) && entry.enclosure_type&.start_with?('image')
      return entry.enclosure_url
    end

    # 3. Fallback: Parse <img> tags embedded inside HTML content/summary
    html_body = entry.content || entry.summary
    return nil unless html_body

    doc = Nokogiri::HTML::DocumentFragment.parse(html_body)
    img_sources = doc.css('img').map { |img| img['src'] }.compact

    # Filter out tracking pixels / transparent GIFs
    img_sources.find do |src|
      !src.include?('tracking') &&
	!src.include?('pixel') &&
	!src.match?(/\.gif$/i)
    end
  end
end
