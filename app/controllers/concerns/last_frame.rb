# Serves the newest bitmap in a set of frames as an image, for the admin
# pages: a panel's last frame, or a dashboard's thumbnail. It only reads,
# never composing a frame. Revalidated on every view, so an unchanged
# frame is a 304 -- answered without reading the bitmap, which is only
# loaded once the browser's copy is stale.
module LastFrame
  extend ActiveSupport::Concern

  private
    def send_last_frame(frames)
      frame = frames.rendered.recent.select(:id, :checksum, :format).first
      return head(:not_found) if frame.nil?
      return unless stale?(etag: frame.checksum)

      send_data Frame.where(id: frame.id).pick(:data), type: frame.content_type, disposition: "inline"
    end
end
