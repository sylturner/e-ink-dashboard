# Merges the expanded occurrences from every source attached to a
# dashboard item into one sorted list. DashboardItem has_many :sources
# already, which is what makes "combine several calendars" work without
# special-casing.
class EventFeed
  # `calendar` is the name the feed publishes (X-WR-CALNAME); `tag` is
  # the short marker from the Source it arrived on, which is what fits
  # beside a title on a 1-bit panel.
  Event = Struct.new(:title, :location, :starts_at, :ends_at,
                     :all_day, :calendar, :tag, keyword_init: true) do
    # The last day the event actually occupies. An all-day event ends at
    # the following midnight, and so does a meeting booked to midnight;
    # neither should light up the next day.
    def last_date
      return ends_at.to_date if ends_at <= starts_at

      ends_at == ends_at.midnight ? (ends_at - 1.second).to_date : ends_at.to_date
    end

    def on?(date)
      starts_at.to_date <= date && last_date >= date
    end

    def multi_day?
      starts_at.to_date != last_date
    end
  end

  def self.for(item, zone:)
    events = item.sources.flat_map { |source|
      Array(source.payload["events"]).filter_map { |raw| build(raw, zone, source.tag) }
    }

    merge_duplicates(events).sort_by { |e| [ e.starts_at, e.title.to_s ] }
  end

  # The same event can reach a tile twice: an invite that lands on two of
  # its calendars, or a feed that lists one meeting twice. Their UIDs
  # can't be trusted to match, so an event is a duplicate when it has
  # the same title (ignoring case and spacing) and the same times. The
  # first copy wins, so a merged event keeps the tag of the source listed
  # first on the tile.
  def self.merge_duplicates(events)
    events.uniq { |e| [ e.title.downcase.squish, e.starts_at, e.ends_at, e.all_day ] }
  end

  def self.build(raw, zone, tag = nil)
    starts, ends = bounds(raw, zone)
    return nil if starts.nil?

    Event.new(
      title: raw["title"].presence || "(untitled)",
      location: raw["location"],
      starts_at: starts,
      ends_at: ends,
      all_day: !!raw["all_day"],
      calendar: raw["calendar"],
      tag: tag
    )
  end

  # All-day entries are rebuilt from their stored dates in the device's
  # zone, so they never drift onto a neighbouring day. Timed entries keep
  # their absolute instant and are simply displayed in the device's zone.
  def self.bounds(raw, zone)
    if raw["all_day"] && raw["start_on"].present?
      starts_on = Date.parse(raw["start_on"])
      ends_on   = Date.parse(raw["end_on"].presence || raw["start_on"])

      [ zone.local(starts_on.year, starts_on.month, starts_on.day),
        zone.local(ends_on.year, ends_on.month, ends_on.day).end_of_day ]
    else
      starts = Time.zone.parse(raw["starts_at"].to_s)&.in_time_zone(zone)
      return [ nil, nil ] if starts.nil?

      [ starts, Time.zone.parse(raw["ends_at"].to_s)&.in_time_zone(zone) || starts ]
    end
  end

  # --- window helpers used by the view partials ---

  def self.on_day(events, date)
    events.select { |e| e.on?(date) }
  end

  def self.between(events, from, to)
    events.select { |e| e.ends_at >= from && e.starts_at <= to }
  end

  def self.upcoming(events, now, limit)
    events.select { |e| e.ends_at >= now }.first(limit)
  end
end
