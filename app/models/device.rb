class Device < ApplicationRecord
  has_secure_token :token

  MIN_SLEEP = 60
  MAX_SLEEP = 6.hours.to_i

  # Every dashboard this panel is allowed to show.
  has_many :device_dashboards, -> { order(:position) }, dependent: :destroy
  has_many :dashboards, through: :device_dashboards

  # The one currently on the panel. Kept in sync below so it is always
  # one of `dashboards`, or nil when none are assigned.
  belongs_to :dashboard, optional: true

  has_many :frames, dependent: :destroy

  after_save :sync_active_dashboard

  validates :name, presence: true
  validates :bit_depth, inclusion: { in: [ 1, 2, 4 ] }
  validates :image_format, inclusion: { in: %w[bmp raw] }
  validates :rotation, inclusion: { in: [ 0, 90, 180, 270 ] }

  def current_frame
    frames.order(rendered_at: :desc).first
  end

  # Dashboards this device could be switched to but is not showing.
  def other_dashboards
    dashboards.where.not(id: dashboard_id)
  end

  def sleep_seconds(at = Time.current)
    hour = at.in_time_zone(time_zone.presence || Time.zone.name).hour
    daytime = (active_from_hour...active_until_hour).cover?(hour)
    daytime ? refresh_seconds : night_refresh_seconds
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
    zone    = time_zone.presence || Time.zone.name
    hour    = at.in_time_zone(zone).hour
    daytime = (active_from_hour...active_until_hour).cover?(hour)
    value   = daytime ? refresh_seconds : night_refresh_seconds

    value.to_i.clamp(MIN_SLEEP, MAX_SLEEP)
  end
end
