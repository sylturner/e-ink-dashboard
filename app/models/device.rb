class Device < ApplicationRecord
  has_secure_token :token

  belongs_to :dashboard, optional: true
  has_many :frames, dependent: :destroy

  validates :name, presence: true
  validates :bit_depth, inclusion: { in: [ 1, 2, 4 ] }
  validates :image_format, inclusion: { in: %w[bmp raw] }
  validates :rotation, inclusion: { in: [ 0, 90, 180, 270 ] }

  def current_frame
    frames.order(rendered_at: :desc).first
  end

  def sleep_seconds(at = Time.current)
    hour = at.in_time_zone(time_zone.presence || Time.zone.name).hour
    daytime = (active_from_hour...active_until_hour).cover?(hour)
    daytime ? refresh_seconds : night_refresh_seconds
  end
end
