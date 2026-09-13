class Devices::LastFramesController < ApplicationController
  # GET /devices/1/last_frame
  #
  # The bitmap a panel was last sent, for its card and page. Unlike
  # FramesController, which the panel itself calls, this only reads: it
  # records no check-in and never composes a frame. Revalidated on every
  # view, so an unchanged frame is a 304.
  def show
    device = Device.find(params.expect(:device_id))
    frame  = device.current_frame
    return head(:not_found) if frame.nil? || frame.data.blank?
    return unless stale?(etag: [ frame.checksum, device.width, device.height ])

    if frame.format == "raw"
      png = raw_png(frame, device)
      png ? send_data(png, type: "image/png", disposition: "inline") : head(:not_found)
    else
      send_data frame.data, type: "image/bmp", disposition: "inline"
    end
  end

  private
    # Browsers can't show a raw frame, so it is drawn to a PNG at the
    # panel's size -- unless the panel has been resized since, and the
    # bytes no longer fit it.
    def raw_png(frame, device)
      Bitmap.from_raw(frame.data, width: device.width, height: device.height).to_png
    rescue ArgumentError
      nil
    end
end
