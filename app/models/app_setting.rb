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
  # every panel out of date. A note tile's QR code links to the server
  # address.
  FRAME_SETTINGS = %w[time_zone clock week_start server_url].freeze

  # "http://192.168.1.10:3000/ " is stored without the slash and spaces, and
  # a cleared field as nil.
  normalizes :server_url, with: -> { it.strip.chomp("/").presence }

  validates :time_zone, presence: true
  validate :server_url_is_an_address, if: :server_url?
  validates :units, inclusion: { in: WeatherProvider::UNITS }
  validates :clock, inclusion: { in: CLOCKS }
  validates :week_start, inclusion: { in: WEEK_STARTS }
  validates :refresh_seconds, :night_refresh_seconds,
            numericality: { only_integer: true, in: MIN_SLEEP..MAX_SLEEP }

  # The headline template a new news tile starts with.
  def news_template
    NewsTemplate.from(self[:news_template].presence || NewsTemplate::DEFAULT)
  end

  def news_template=(value)
    self[:news_template] = NewsTemplate.from(value).to_h
  end

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

  # The server address as url_for options, for links drawn on a panel: a
  # frame is often rendered in a job, with no request to take a host from.
  # Nil until the address is set.
  def url_options
    return unless server_url?

    uri = URI.parse(server_url)
    { protocol: uri.scheme, host: uri.host, port: uri.port }
  end

  private

    # A scheme, a host and an optional port, and nothing after them: the
    # routes supply the path.
    def server_url_is_an_address
      uri = URI.parse(server_url)
      return if uri.is_a?(URI::HTTP) && uri.host.present? && uri.path.empty? &&
                [ uri.userinfo, uri.query, uri.fragment ].none?

      errors.add(:server_url, :not_an_address)
    rescue URI::InvalidURIError
      errors.add(:server_url, :not_an_address)
    end
end
