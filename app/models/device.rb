class Device < ApplicationRecord
  include CheckInSchedule

  has_secure_token :token

  # How often an unclaimed panel comes back to ask, so assigning a
  # dashboard feels immediate rather than like a fault.
  UNCLAIMED_SLEEP = 120

  # Omits I, L, O, 0, 1 -- those get misread off a low-res panel.
  CLAIM_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze

  BIT_DEPTHS    = [ 1, 2, 4 ].freeze
  IMAGE_FORMATS = %w[bmp png].freeze
  ROTATIONS     = [ 0, 90, 180, 270 ].freeze

  # TRMNL's firmware decodes a BMP only at this size; any other panel is
  # sent PNG.
  BMP_SIZE = [ 800, 480 ].freeze

  # A LiPo's voltage from empty to full, for estimating its charge.
  BATTERY_VOLTS = 3.30..4.20

  # The settings a frame is rendered from: changing one leaves the frame
  # on the panel out of date. Rotation isn't used when rendering.
  FRAME_SETTINGS = %w[dashboard_id width height bit_depth image_format dither time_zone show_navigation].freeze

  # Where a dashboard sits among a panel's, for the navigation strip
  # (renders/_navigation): the panel's dashboards in order, and the index
  # of the one drawn. Stepping past either end wraps around.
  Navigation = Data.define(:dashboards, :index) do
    def current = dashboards[index]
    def previous_dashboard = dashboards[index - 1]
    def next_dashboard = dashboards[(index + 1) % count]
    def position = index + 1
    def count = dashboards.size
  end

  # Every dashboard this panel is allowed to show, in the order a dial or
  # the special function steps through them.
  has_many :device_dashboards, -> { order(:position, :id) }, dependent: :destroy
  has_many :dashboards, through: :device_dashboards

  # The one currently on the panel. Kept in sync below so it is always
  # one of `dashboards`, or nil when none are assigned.
  belongs_to :dashboard, optional: true

  has_many :frames, dependent: :destroy

  scope :claimed, -> { where.not(dashboard_id: nil) }

  after_save :sync_active_dashboard

  # Every device needs a code, not just self-enrolled ones: an unclaimed
  # panel shows it on the setup screen however the row got there.
  before_create :assign_claim_code

  validates :name, presence: true
  validates :bit_depth, inclusion: { in: BIT_DEPTHS }
  validates :image_format, inclusion: { in: IMAGE_FORMATS }
  validate :bmp_fits_the_firmware, if: -> { image_format == "bmp" }
  validates :rotation, inclusion: { in: ROTATIONS }

  # "none" keeps the plain black/white threshold.
  DITHER_OPTIONS = [ "none", *Dither::ALGORITHMS ].freeze
  validates :dither, inclusion: { in: DITHER_OPTIONS }

  # Idempotent by MAC, so a device retrying after a timeout does not
  # create duplicates and a re-flashed one reattaches to its old row.
  def self.enroll!(mac:, attributes: {})
    normalized = mac.to_s.downcase.strip
    device = find_or_initialize_by(mac_address: normalized)

    if device.new_record?
      device.assign_attributes(attributes)
      device.name = "Panel #{normalized.tr(':', '').last(4).upcase}" if device.name.blank?
      device.enrolled_at = Time.current
    else
      # Re-enrollment after a factory reset: refresh what the hardware
      # reports, keep the dashboard assignments and frame history.
      device.assign_attributes(
        attributes.slice(:width, :height, :bit_depth, :image_format, :firmware_version)
      )

      # A schedule saved before it was validated would fail this save, and
      # the panel could never re-enroll, so it falls back to the defaults.
      device.time_zone = nil unless known_time_zone?(device.time_zone)
      device.active_from_hour = column_defaults["active_from_hour"] unless DAYTIME_START_HOURS.cover?(device.active_from_hour)
      device.active_until_hour = column_defaults["active_until_hour"] unless DAYTIME_END_HOURS.cover?(device.active_until_hour)
    end

    device.save!
    device
  end

  def self.generate_claim_code
    loop do
      code = Array.new(4) { CLAIM_ALPHABET.sample }.join
      break code unless exists?(claim_code: code)
    end
  end

  # The format TRMNL's firmware can decode at a panel's size.
  def self.image_format_for(width, height)
    [ width, height ] == BMP_SIZE ? "bmp" : "png"
  end

  # The charge a battery voltage suggests, on a rough linear curve: good
  # enough to decide "charge it soon", not to trust below about 20%.
  # Most panels report only the voltage. Nil when there's no reading.
  def self.battery_percent_for(volts)
    return if volts.nil? || volts <= 0.1

    ((volts - BATTERY_VOLTS.begin) / (BATTERY_VOLTS.end - BATTERY_VOLTS.begin) * 100).clamp(0, 100).round
  end

  # A panel is claimed once it has something to show.
  def claimed?
    dashboard_id.present?
  end

  # What Bitmap.from_png expects: an algorithm name, or nil to threshold.
  def dither_algorithm
    dither unless dither == "none"
  end

  def current_frame
    frames.order(rendered_at: :desc).first
  end

  # Dashboards this device could be switched to but is not showing.
  def other_dashboards
    dashboards.where.not(id: dashboard_id)
  end

  # The active dashboard is meaningless unless it is also assigned, so
  # reconcile the two rather than rejecting the save: fall back to the
  # first assignment, or to nil when the last one goes away.
  #
  # Public because assignments are usually created and destroyed through
  # DeviceDashboard, which never saves the device itself.
  def sync_active_dashboard
    assigned = DeviceDashboard.where(device_id: id).order(:position, :id).pluck(:dashboard_id)

    wanted = if assigned.empty?
      nil
    elsif dashboard_id.present? && assigned.include?(dashboard_id)
      dashboard_id
    else
      assigned.first
    end

    update_column(:dashboard_id, wanted) unless wanted == dashboard_id
  end

  # Moves the panel `steps` through its dashboards: forward for a positive
  # number, back for a negative one, wrapping around at either end.
  def step_dashboard!(steps)
    ids = device_dashboards.pluck(:dashboard_id)
    return if ids.empty? || steps.zero?

    index = ids.index(dashboard_id) || (steps.positive? ? -1 : 0)
    update_columns(dashboard_id: ids[(index + steps) % ids.size])
  end

  # The strip drawn under `dashboard` on this panel, or nil when the panel
  # doesn't draw one or the dashboard isn't one of its own. The dashboard
  # passed stands in for its saved copy, so the builder's preview names
  # it as it is being edited.
  def navigation(dashboard = self.dashboard)
    return unless show_navigation? && dashboard

    dashboards = self.dashboards.map { it.id == dashboard.id ? dashboard : it }
    index = dashboards.index(dashboard)
    Navigation.new(dashboards:, index:) if index
  end

  def request_refresh!
    update_columns(refresh_requested_at: Time.current)
  end

  # Whether the last save changed anything in FRAME_SETTINGS.
  def frame_settings_changed?
    saved_changes.keys.intersect?(FRAME_SETTINGS)
  end

  # The time on the panel's clock: in its own zone, or the app's.
  def local_time(at = Time.current)
    at.in_time_zone(time_zone.presence || Time.zone)
  end

  def sleep_seconds(at = Time.current)
    return UNCLAIMED_SLEEP unless claimed?

    daytime = (active_from_hour...active_until_hour).cover?(local_time(at).hour)
    value   = daytime ? refresh_seconds : night_refresh_seconds

    value.to_i.clamp(MIN_SLEEP, MAX_SLEEP)
  end

  # When the panel should check in again: the sleep it was given the last
  # time it did. Nil until it first checks in.
  def next_check_in_at
    last_seen_at && last_seen_at + sleep_seconds(last_seen_at)
  end

  # It has missed a check-in: twice the sleep it was given has passed, so
  # a slow Wi-Fi join or a late wake doesn't count.
  def overdue?(now = Time.current)
    last_seen_at.present? && now > last_seen_at + 2 * sleep_seconds(last_seen_at)
  end

  private

    def assign_claim_code
      self.claim_code = self.class.generate_claim_code if claim_code.blank?
    end

    def bmp_fits_the_firmware
      return if self.class.image_format_for(width, height) == "bmp"

      errors.add(:image_format, :bmp_size, size: BMP_SIZE.join("×"))
    end
end
