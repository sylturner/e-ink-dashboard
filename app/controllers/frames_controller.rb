class FramesController < ApplicationController
  def show
    png   = BrowserPool.capture(html: dashboard_html)
    frame = Frame.from_png(png)

    send_data frame.to_bmp, type: "image/bmp", disposition: "inline"
  end

  private

  def dashboard_html
    ApplicationController.renderer.render(
      template: "renders/dashboard",
      layout: "render",
      assigns: { now: Time.current }
    )
  end
end
