class Frame < ApplicationRecord
  belongs_to :device

  before_validation :set_metadata

  scope :recent, -> { order(rendered_at: :desc) }

  private

  def set_metadata
    return if data.blank?

    self.checksum   = Digest::SHA256.hexdigest(data)
    self.byte_size  = data.bytesize
    self.rendered_at ||= Time.current
  end
end
