# A list that takes turns, one entry a day or a week: a chore wheel, whose
# turn it is to cook, a quote of the day. The entry showing is worked out
# from the panel's date and the day the first entry was shown, so nothing
# has to run to move it on.
class Rotation
  PERIODS = %w[daily weekly].freeze

  attr_reader :entries

  # `entries` is the inspector's text, one per line; `start` the day the
  # first one showed, year-month-day. A week starts on the app's week
  # start, so a weekly turn changes on that day.
  def initialize(entries:, period:, start:, today:)
    @entries = entries.to_s.lines.map(&:strip).compact_blank
    @weekly  = period.to_s == "weekly"
    @start   = parse_date(start) || today
    @today   = today
  end

  def any?
    entries.any?
  end

  # Where the list is up to, 0 for the first entry. Before the start, it
  # counts back through the list.
  def index
    return 0 if entries.empty?

    turns % entries.size
  end

  def current
    entries[index]
  end

  # The entry after the current one, or nil when there's only one.
  def upcoming
    entries[(index + 1) % entries.size] if entries.size > 1
  end

  private

    def turns
      return (@today - @start).to_i unless @weekly

      (@today.beginning_of_week - @start.beginning_of_week).to_i / 7
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
end
