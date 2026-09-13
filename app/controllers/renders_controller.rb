class RendersController < ApplicationController
  layout "render"

  # GET /render/dashboard(?dashboard_id=N)
  #
  # The builder's preview iframe passes the dashboard it is editing.
  # Without it, fall back to whatever the first device is showing.
  def dashboard
    @dashboard = Dashboard.find_by(id: params[:dashboard_id])
    @device    = @dashboard ? @dashboard.devices.first : Device.first
    @dashboard ||= @device&.dashboard || Dashboard.first
    # The panel's clock, as FrameComposer draws it.
    @now       = @device ? @device.local_time : Time.current
  end
end
