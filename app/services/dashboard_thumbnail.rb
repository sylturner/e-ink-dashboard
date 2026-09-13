# A PNG of a dashboard as its panel shows it, for the dashboard list.
#
# Captures share the headless Chrome that renders device frames and take
# most of a second each, so a capture is cached under a digest of the
# render HTML. It is only captured again once something on the dashboard
# has changed -- a tile, the theme, fetched data, or the minute on a clock.
class DashboardThumbnail
  def initialize(dashboard)
    @dashboard = dashboard
  end

  def digest
    @digest ||= Digest::SHA256.hexdigest(html)
  end

  def png
    Rails.cache.fetch([ "dashboard_thumbnail", digest ], expires_in: 1.hour) do
      width, height = @dashboard.screen_size
      BrowserPool.capture(html: html, width: width, height: height)
    end
  end

  private

  def html
    @html ||= FrameComposer.html(dashboard: @dashboard, device: @dashboard.devices.first)
  end
end
