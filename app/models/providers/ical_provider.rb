class IcalProvider < ApplicationRecord
  include Providable

  # The secret iCal address is a bearer credential: anyone holding it can
  # read the calendar. Encrypted at rest, non-deterministically, since
  # nothing ever queries by it. An uploaded .ics file is the same secret
  # in another shape, so its contents are encrypted too.
  encrypts :ical_url
  encrypts :ics_data

  provides label:           "Calendar (iCal)",
           attributes:      %i[ical_url include_all_day],
           refresh_seconds: 900

  # ics_file is the uploaded .ics; remove_ics is the checkbox that drops
  # a previously uploaded file. Neither is a stored column.
  def self.extra_params
    %i[ics_file remove_ics]
  end

  WINDOW_BACK    = 1.day
  WINDOW_FORWARD = 60.days
  MAX_EVENTS     = 500
  MAX_ICS_BYTES  = 5.megabytes

  attr_accessor :remove_ics

  validate  :url_or_file
  validate  :ics_data_size
  validates :ical_url, allow_blank: true,
            format: { with: %r{\A(https?|webcal)://\S+\z} }

  before_validation :drop_uploaded_file, if: -> { ActiveModel::Type::Boolean.new.cast(remove_ics) }

  def self.defaults
    { include_all_day: true }
  end

  # file_field/check_box read the getter; there is nothing to prefill for
  # an upload, so it always reads back empty.
  def ics_file
    nil
  end

  # Accepts the uploaded .ics. A blank value -- the empty file input when
  # nothing was chosen -- is ignored so an edit that only touches other
  # fields keeps the calendar already on file.
  def ics_file=(uploaded)
    return if uploaded.blank?

    self.ics_data     = uploaded.read
    self.ics_filename = uploaded.original_filename if uploaded.respond_to?(:original_filename)
  end

  def uploaded?
    ics_data.present?
  end

  def detail
    return "File: #{ics_filename.presence || 'calendar.ics'}" if uploaded?

    ical_url.to_s.truncate(50)
  end

  # Recurrence is expanded here rather than at render time: renders run
  # on the hot path under the BrowserPool mutex, and expanding RRULEs
  # across a 60-day window there would be the wrong place for it. The
  # payload holds concrete, already-expanded occurrences.
  def fetch!
    body      = ics_data.presence || Http.get(normalized_url)
    calendars = parse(body)
    raise Http::Error, "no calendar data" if calendars.blank?

    from = Time.current.beginning_of_day - WINDOW_BACK
    to   = Time.current + WINDOW_FORWARD

    events = calendars.flat_map do |calendar|
      label = calendar_name(calendar)
      calendar.events.flat_map { |event| expand(event, label, from, to) }
    end

    events = events.compact
                   .sort_by { |e| [ e["starts_at"], e["title"].to_s ] }
                   .first(MAX_EVENTS)

    {
      "events"      => events,
      "window_from" => from.iso8601,
      "window_to"   => to.iso8601,
      "count"       => events.size
    }
  end

  private

    def url_or_file
      return if ical_url.present? || ics_data.present?

      errors.add(:base, "Add a secret iCal URL or upload an .ics file")
    end

    def drop_uploaded_file
      self.ics_data     = nil
      self.ics_filename = nil
    end

    def ics_data_size
      return if ics_data.blank? || ics_data.bytesize <= MAX_ICS_BYTES

      errors.add(:base, "The .ics file is too large (max #{MAX_ICS_BYTES / 1.megabyte} MB)")
    end

    # Parsing is all-or-nothing in the icalendar gem: a single malformed
    # DTSTART raises before any event is reachable, so the per-event
    # rescue in #expand cannot help here. Convert it into an Http::Error
    # so record_failure fires and the tile keeps its last good payload
    # rather than blanking.
    def parse(body)
      Icalendar::Calendar.parse(body)
    rescue Http::Error
      raise
    rescue StandardError => e
      raise Http::Error, "could not parse calendar: #{e.message.truncate(120)}"
    end

    # webcal:// is just https:// with a scheme that tells the OS to
    # subscribe. Rewrite it so Net::HTTP accepts it.
    def normalized_url
      ical_url.sub(/\Awebcal:/i, "https:")
    end

    def calendar_name(calendar)
      calendar.x_wr_calname&.first.to_s.presence || source&.name || "Calendar"
    end

    # One malformed entry in a shared calendar must not blank the tile,
    # so a failed event is skipped rather than failing the whole fetch.
    def expand(event, label, from, to)
      occurrences(event, from, to).filter_map do |starts, ends, all_day|
        next if starts.nil?
        next unless ends >= from && starts <= to

        {
          "uid"       => event.uid.to_s,
          "title"     => sanitize(event.summary),
          "location"  => sanitize(event.location),
          "starts_at" => starts.iso8601,
          "ends_at"   => ends.iso8601,
          "all_day"   => all_day,
          # All-day entries carry their plain dates as well. Converting a
          # midnight timestamp into the device's zone is exactly what
          # lands a bin day on the wrong square.
          "start_on"  => (starts.to_date.iso8601 if all_day),
          "end_on"    => (all_day_last_date(starts, ends).iso8601 if all_day),
          "calendar"  => label
        }.compact
      end
    rescue StandardError => e
      Rails.logger.warn("[iCal] skipped #{event.uid}: #{e.message}")
      []
    end

    # DTEND is exclusive for DATE values: a one-day event ends on the
    # following midnight.
    def all_day_last_date(starts, ends)
      last = ends.to_date - 1
      last < starts.to_date ? starts.to_date : last
    end

    def occurrences(event, from, to)
      all_day = all_day?(event)

      if event.rrule.present?
        event.occurrences_between(from, to).map do |occurrence|
          [ to_time(occurrence.start_time), to_time(occurrence.end_time), all_day ]
        end
      else
        starts = to_time(event.dtstart)
        ends   = to_time(event.dtend) || starts
        [ [ starts, ends, all_day ] ]
      end
    end

    # A DTSTART with a DATE value (no time component) is an all-day event.
    def all_day?(event)
      event.dtstart.is_a?(Icalendar::Values::Date)
    end

    def to_time(value)
      return nil if value.nil?

      case value
      when Icalendar::Values::Date
        value.to_date.in_time_zone(zone).beginning_of_day
      when Icalendar::Values::DateTime
        value.to_time.in_time_zone(zone)
      when ::Date
        # icalendar-recurrence hands back plain Dates for all-day series.
        value.in_time_zone(zone).beginning_of_day
      else
        value.respond_to?(:to_time) ? value.to_time.in_time_zone(zone) : nil
      end
    end

    def zone
      Time.zone
    end

    def sanitize(text)
      return nil if text.blank?

      text.to_s.gsub(/\s+/, " ").strip.presence
    end
end
