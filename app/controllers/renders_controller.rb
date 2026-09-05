class RendersController < ApplicationController
  layout "render"

  def dashboard
    @now = Time.current
  end
end
