# How long until a day, or how long since it, as a countdown tile draws
# it at the panel's time. Counted in days, or in days and hours up to a
# time of day. On the day itself it's "today"; after it, days since.
class Countdown
  UNITS = %w[days hours].freeze

  attr_reader :date, :now

  # `date` is year-month-day and `time` hours:minutes, as the inspector's
  # fields send them. A blank time is the start of the day.
  def initialize(date:, time: nil, unit: "days", now:)
    @now  = now
    @unit = UNITS.include?(unit.to_s) ? unit.to_s : "days"
    @date = parse_date(date)
    @time = time.to_s[/\A\d{1,2}:\d{2}\z/]
  end

  def valid?
    date.present?
  end

  # :ahead, :today or :past. In hours, the day stays ahead until its time.
  def state
    return :ahead if hours? && target > now
    return :ahead if date > today
    return :today if date == today

    :past
  end

  # What's left, largest unit first, as { days:, hours:, minutes: } with
  # only the ones to draw: whole days (calendar days, counting in days),
  # then hours, leaving out a zero, and minutes when less than an hour is
  # left.
  def remaining
    return { days: (date - today).to_i } unless hours?

    seconds = (target - now).to_i
    days, seconds  = seconds.divmod(1.day.to_i)
    hours, seconds = seconds.divmod(1.hour.to_i)
    left = { days:, hours: }.reject { |_unit, count| count.zero? }

    left.presence || { minutes: [ seconds / 60, 1 ].max }
  end

  # Whole days since the day, once it's past.
  def days_since
    (today - date).to_i
  end

  private

    def hours?
      @unit == "hours"
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def today
      now.to_date
    end

    # The moment counted down to, in the panel's time zone.
    def target
      now.time_zone.parse("#{date.iso8601} #{@time || '00:00'}")
    end
end
