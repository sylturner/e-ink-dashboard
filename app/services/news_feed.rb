# Merges the items from every feed attached to a news tile into one list,
# newest first, the way EventFeed merges calendars.
class NewsFeed
  def self.for(item)
    entries = item.sources.flat_map do |source|
      Array(source.payload["items"]).grep(Hash).map { |entry| [ entry, published_at(entry) || source.fetched_at ] }
    end

    # Undated items (a feed that only ever holds the current moon phase)
    # count as new as of their source's last fetch. Ties keep the tile's
    # source order, then each feed's own.
    sorted = entries.each_with_index.sort_by { |(_, at), index| [ -at.to_f, index ] }

    merge_duplicates(sorted.map { |(entry, _), _| entry })
  end

  # The same story can arrive on two feeds (a topic feed and the front
  # page). It's the same story when it links to the same page, and the
  # newer copy, already first, wins.
  def self.merge_duplicates(entries)
    entries.uniq { |entry| entry["url"].presence || entry.object_id }
  end

  def self.published_at(entry)
    Time.iso8601(entry["published_at"].to_s)
  rescue ArgumentError
    nil
  end
end
