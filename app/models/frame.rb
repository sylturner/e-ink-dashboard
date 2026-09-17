class Frame < ApplicationRecord
  belongs_to :device
  # What it was rendered from; nil for an unclaimed panel's setup screen.
  belongs_to :dashboard, optional: true

  before_validation :set_metadata

  scope :recent, -> { order(rendered_at: :desc) }
  scope :rendered, -> { where.not(data: nil) }

  # What a panel calls the image. It follows the pixels rather than the
  # row, so a re-render that draws the same image keeps the name and the
  # panel skips the download. Short: TRMNL's firmware keeps it in a
  # 36-byte buffer.
  def filename
    "#{checksum.first(24)}.#{format}"
  end

  def content_type
    format == "png" ? "image/png" : "image/bmp"
  end

  private

  def set_metadata
    return if data.blank?

    self.checksum   = Digest::SHA256.hexdigest(data)
    self.byte_size  = data.bytesize
    self.rendered_at ||= Time.current
  end
end
