# A time of the week when one of a panel's dashboards goes on it by
# itself: on some days, from one time until another. An end at or before
# the start runs into the next day, so 22:00-06:00 is overnight and
# 00:00-00:00 is the whole day. DashboardSchedule decides between slots.
class ScheduleSlot < ApplicationRecord
  DAYS = (0..6)
  WEEKDAYS = [ 1, 2, 3, 4, 5 ].freeze
  WEEKEND = [ 0, 6 ].freeze

  # What its form edits. The assignment is picked from the panel's own.
  FORM_ATTRIBUTES = [ :device_dashboard_id, :from_time, :until_time, { days: [] } ].freeze

  belongs_to :device_dashboard
  has_one :device, through: :device_dashboard
  has_one :dashboard, through: :device_dashboard

  delegate :dashboard_id, to: :device_dashboard

  # A form sends the checked days as strings, after a blank for none.
  normalizes :days, with: ->(days) { Array(days).compact_blank.map(&:to_i).uniq.sort }

  validates :days, presence: true
  validate :days_of_the_week
  validates :from_time, :until_time, presence: true

  # "06:30", for a time field, or nil when unset.
  def from_time = clock(from_minute)
  def until_time = clock(until_minute)

  # A time field sends "06:30"; anything else unsets it.
  def from_time=(value)
    self.from_minute = minute(value)
  end

  def until_time=(value)
    self.until_minute = minute(value)
  end

  private

    def clock(minutes)
      format("%02d:%02d", *minutes.divmod(60)) if minutes
    end

    def minute(value)
      hours, minutes = value.to_s.match(/\A(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?\z/)&.captures&.map(&:to_i)
      hours * 60 + minutes if hours && hours < 24 && minutes < 60
    end

    def days_of_the_week
      errors.add(:days, :inclusion) unless days.all? { DAYS.cover?(it) }
    end
end
