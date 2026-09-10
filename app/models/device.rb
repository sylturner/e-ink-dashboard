class Device < ApplicationRecord
  has_secure_token :token

  MIN_SLEEP = 60
  MAX_SLEEP = 6.hours.to_i

  # How often an unclaimed panel comes back to ask, so assigning a
  # dashboard feels immediate rather than like a fault.
  UNCLAIMED_SLEEP = 120

  # Omits I, L, O, 0, 1 -- those get misread off a low-res panel.
  CLAIM_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze

  # Every dashboard this panel is allowed to show.
  has_many :device_dashboards, -> { order(:position) }, dependent: :destroy
  has_many :dashboards, through: :device_dashboards

  # The one currently on the panel. Kept in sync below so it is always
  # one of `dashboards`, or nil when none are assigned.
  belongs_to :dashboard, optional: true

  has_many :frames, dependent: :destroy

  after_save :sync_active_dashboard

  # Every device needs a code, not just self-enrolled ones: an unclaimed
  # panel shows it on the setup screen however the row got there.
  before_create :assign_claim_code

  validates :name, presence: true
  validates :bit_depth, inclusion: { in: [ 1, 2, 4 ] }
  validates :image_format, inclusion: { in: %w[bmp raw] }
  validates :rotation, inclusion: { in: [ 0, 90, 180, 270 ] }

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
    assigned = DeviceDashboard.where(device_id: id).order(:position).pluck(:dashboard_id)

    wanted = if assigned.empty?
      nil
    elsif dashboard_id.present? && assigned.include?(dashboard_id)
      dashboard_id
    else
      assigned.first
    end

    update_column(:dashboard_id, wanted) unless wanted == dashboard_id
  end

  # Cycles through every dashboard, ordered by name. If you later want a
  # per-device subset, this is the method to change.
  def advance_dashboard!
    ids = Dashboard.order(:name).pluck(:id)
    return if ids.empty?

    index = ids.index(dashboard_id) || -1
    update_columns(dashboard_id: ids[(index + 1) % ids.size])
  end

  def request_refresh!
    update_columns(refresh_requested_at: Time.current)
  end

  def sleep_seconds(at = Time.current)
    return UNCLAIMED_SLEEP unless claimed?

    zone    = time_zone.presence || Time.zone.name
    hour    = at.in_time_zone(zone).hour
    daytime = (active_from_hour...active_until_hour).cover?(hour)
    value   = daytime ? refresh_seconds : night_refresh_seconds

    value.to_i.clamp(MIN_SLEEP, MAX_SLEEP)
  end

  private

    def assign_claim_code
      self.claim_code = self.class.generate_claim_code if claim_code.blank?
    end
end
