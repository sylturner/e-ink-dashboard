# Uploaded images drawn on a panel. A frame is rendered with no request to
# fetch through, so an image goes into the page as a data: URI, a copy no
# larger than the panel needs. It stays in color: Bitmap grays the whole
# frame before the panel's dithering takes it to 1-bit.
module PanelImagesHelper
  # The largest a photo tile's photo is drawn: bigger than any tile, and
  # not so big that every frame carries megabytes.
  PHOTO_LIMIT = [ 1600, 1600 ].freeze

  # A copy of `blob` within `limit`, turned upright, as a data: URI. An
  # image that can't be read is left out rather than stopping the whole
  # frame.
  def panel_image_data_uri(blob, limit:, format: :png)
    variant = blob.variant(resize_to_limit: limit, format:).processed
    "data:#{Marcel::MimeType.for(extension: format.to_s)};base64,#{Base64.strict_encode64(variant.download)}"
  rescue StandardError => error
    Rails.logger.warn("Couldn't draw image #{blob.id}: #{error.class}: #{error.message}")
    nil
  end
end
