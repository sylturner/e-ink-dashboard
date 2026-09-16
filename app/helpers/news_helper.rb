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

  # When an upcoming event happens, as a newspaper's events box prints
  # it: "Today · 1:00 PM", "Tomorrow · All day", "Today · Now" for one
  # already under way.
  def newspaper_event_when(event, now)
    date = [ event.starts_at.to_date, now.to_date ].max
    day  = case (date - now.to_date).to_i
    when 0 then t("renders.newspaper.today")
    when 1 then t("renders.newspaper.tomorrow")
    else l(date, format: :panel_weekday)
    end

    time = if event.all_day then t("renders.newspaper.all_day")
    elsif event.starts_at <= now then t("renders.newspaper.now")
    else panel_time(event.starts_at, :time)
    end

    t("renders.newspaper.event_when", day:, time:)
  end

  private

    # Dates and ages are drawn in the panel's zone, from the moment the
    # frame is rendered for.
    def published_in_zone(entry, now)
      NewsFeed.published_at(entry)&.in_time_zone(now.time_zone)
    end
end
