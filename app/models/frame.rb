class Frame < ApplicationRecord
  belongs_to :device
  # What it was rendered from; nil for an unclaimed panel's setup screen.
  belongs_to :dashboard, optional: true

  before_validation :set_metadata

  scope :recent, -> { order(rendered_at: :desc) }
  scope :rendered, -> { where.not(data: nil) }

  private

  def set_metadata
    return if data.blank?

    self.checksum   = Digest::SHA256.hexdigest(data)
    self.byte_size  = data.bytesize
    self.rendered_at ||= Time.current
  end
end
