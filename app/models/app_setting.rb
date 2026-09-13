# The app's own settings: a single row, read through AppSetting.current.
#
# Requests and jobs run inside #apply (ApplicationController,
# ApplicationJob), so Time.zone and Date.beginning_of_week already follow
# these settings, and a panel without a zone of its own reads the app's.
class AppSetting < ApplicationRecord
  include CheckInSchedule

  CLOCKS      = %w[12h 24h].freeze
  WEEK_STARTS = %w[sunday monday].freeze

  # The settings a frame is drawn with: changing one leaves the frame on
  # every panel out of date.
  FRAME_SETTINGS = %w[time_zone clock week_start].freeze

  validates :time_zone, presence: true
  validates :units, inclusion: { in: WeatherProvider::UNITS }
  validates :clock, inclusion: { in: CLOCKS }
  validates :week_start, inclusion: { in: WEEK_STARTS }
  validates :refresh_seconds, :night_refresh_seconds,
            numericality: { only_integer: true, in: MIN_SLEEP..MAX_SLEEP }

  # Loaded once per request or job; Current is reset between them.
  def self.current
    Current.app_setting ||= first_or_create!
  end

  # What a panel added by hand or by enrolling starts with.
  def panel_defaults
    slice(*SCHEDULE_ATTRIBUTES).symbolize_keys
  end

  # Runs the block in the app's time zone and week.
  def apply(&block)
    previous_week_start = Date.beginning_of_week
    Date.beginning_of_week = week_start.to_sym

    Time.use_zone(time_zone, &block)
  ensure
    Date.beginning_of_week = previous_week_start
  end

  # Whether the last save changed anything in FRAME_SETTINGS.
  def frame_settings_changed?
    saved_changes.keys.intersect?(FRAME_SETTINGS)
  end
end
