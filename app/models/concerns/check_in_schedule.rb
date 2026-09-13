# The schedule a panel checks in by, and the zone it reads its hours in.
# Device has one per panel; AppSetting holds the one new panels start with
# and the zone panels without their own follow.
module CheckInSchedule
  extend ActiveSupport::Concern

  MIN_SLEEP = 60
  MAX_SLEEP = 6.hours.to_i

  # Daytime runs from the start hour up to, but not including, the end
  # hour, so it can end at midnight (24).
  DAYTIME_START_HOURS = (0..23)
  DAYTIME_END_HOURS   = (1..24)

  SCHEDULE_ATTRIBUTES = %w[refresh_seconds night_refresh_seconds active_from_hour active_until_hour].freeze

  included do
    # Stored as IANA names ("America/New_York"), which Open-Meteo reads too,
    # even when given one of Rails' ("Eastern Time (US & Canada)").
    normalizes :time_zone, with: ->(zone) { zone.presence && ActiveSupport::TimeZone::MAPPING.fetch(zone, zone) }

    validates :active_from_hour, inclusion: { in: DAYTIME_START_HOURS }
    validates :active_until_hour, inclusion: { in: DAYTIME_END_HOURS }

    # The schedule and the render both read the panel's clock in this zone,
    # so an unknown one would make every check-in fail.
    validate :time_zone_known
  end

  class_methods do
    # Blank is allowed: a panel without a zone follows the app's.
    def known_time_zone?(name)
      name.blank? || ActiveSupport::TimeZone[name].present?
    end
  end

  private

    def time_zone_known
      errors.add(:time_zone, "isn't a time zone name") unless self.class.known_time_zone?(time_zone)
    end
end
