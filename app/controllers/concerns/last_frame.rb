# Serves the newest bitmap in a set of frames as an image, for the admin
# pages: a panel's last frame, or a dashboard's thumbnail. It only reads,
# never composing a frame. Revalidated on every view, so an unchanged
# frame is a 304 -- answered without reading the bitmap, which is only
# loaded once the browser's copy is stale.
module LastFrame
  extend ActiveSupport::Concern

  private
    def send_last_frame(frames)
      frame = frames.rendered.recent.select(:id, :device_id, :checksum, :format).first
      return head(:not_found) if frame.nil?

      device = frame.device
      return unless stale?(etag: [ frame.checksum, device.width, device.height ])

      data = Frame.where(id: frame.id).pick(:data)

      if frame.format == "raw"
        png = raw_png(data, device)
        png ? send_data(png, type: "image/png", disposition: "inline") : head(:not_found)
      else
        send_data data, type: "image/bmp", disposition: "inline"
      end
    end

    # Browsers can't show a raw frame, so it is drawn to a PNG at the
    # panel's size -- unless the panel has been resized since, and the
    # bytes no longer fit it.
    def raw_png(data, device)
      Bitmap.from_raw(data, width: device.width, height: device.height).to_png
    rescue ArgumentError
      nil
    end
end
