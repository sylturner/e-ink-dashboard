class Dashboards::ThumbnailsController < ApplicationController
  # GET /dashboards/1/thumbnail.png
  #
  # Revalidated on every view. The ETag is the render digest, so while a
  # dashboard is unchanged the browser gets a 304 without a capture.
  def show
    thumbnail = DashboardThumbnail.new(Dashboard.find(params.expect(:dashboard_id)))
    return unless stale?(etag: thumbnail.digest)

    if (png = capture(thumbnail))
      send_data png, type: "image/png", disposition: "inline"
    else
      head :service_unavailable
    end
  end

  private
    # Like FramesController, a failed capture is logged rather than raised.
    # The list shows the image's alt text in its place.
    def capture(thumbnail)
      thumbnail.png
    rescue StandardError => e
      Rails.logger.error("[Thumbnails] capture failed: #{e.class}: #{e.message}")
      nil
    end
end
