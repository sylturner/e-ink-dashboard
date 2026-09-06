class RendersController < ApplicationController
  layout "render"

  def dashboard
    @device    = Device.first
    @dashboard = @device&.dashboard || Dashboard.first
    @now       = Time.current
  end
end
