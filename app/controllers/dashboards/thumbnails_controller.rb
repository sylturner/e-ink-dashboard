class Dashboards::ThumbnailsController < ApplicationController
  include LastFrame

  # GET /dashboards/1/thumbnail.png
  #
  # The newest frame any panel was sent of the dashboard. It can be a
  # little stale, but capturing a fresh one in headless Chrome would keep
  # the list waiting.
  def show
    send_last_frame(Dashboard.find(params.expect(:dashboard_id)).frames)
  end
end
