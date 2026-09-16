module NewsHelper
  # One line of a headline template filled from a NewsFeed entry, or nil
  # when it has nothing to draw.
  def headline_line(line, entry, now)
    published = published_in_zone(entry, now)

    NewsTemplate.fill(line.tokens, entry, named: {
      "date" => published && panel_date(published),
      "age"  => published && panel_age(published, now)
    })
  end

  # A story's source and age, "NPR News · 2h", as a newspaper prints its
  # byline. It names the source as it was named here: a feed's own title
  # can be a mouthful ("site:reuters.com" - Google News).
  def news_byline(entry, now)
    published = published_in_zone(entry, now)

    [ entry["source_name"], published && panel_age(published, now) ].compact_blank.join(" · ").presence
  end

  private

    # Dates and ages are drawn in the panel's zone, from the moment the
    # frame is rendered for.
    def published_in_zone(entry, now)
      NewsFeed.published_at(entry)&.in_time_zone(now.time_zone)
    end
end
