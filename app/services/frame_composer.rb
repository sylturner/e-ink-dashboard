# app/services/frame_composer.rb
class FrameComposer
  KEEP_FRAMES = 3

  def self.call(device)
    new(device).call
  end

  # The page a panel is captured from, at the device's local time.
  # DashboardThumbnail captures the same page for the dashboard list.
  def self.html(dashboard:, device:, template: "renders/dashboard")
    ApplicationController.renderer.render(
      template: template,
      layout: "render",
      assigns: {
        dashboard: dashboard,
        device: device,
        now: Time.current.in_time_zone(device&.time_zone.presence || Time.zone.name)
      }
    )
  end

  def initialize(device)
    @device = device
  end

  def call
    png    = BrowserPool.capture(html: html, width: @device.width, height: @device.height)
    bitmap = Bitmap.from_png(png, bit_depth: @device.bit_depth, dither: @device.dither_algorithm)
    bytes  = bitmap.to_format(@device.image_format)

    frame = @device.frames.create!(
      data: bytes,
      format: @device.image_format,
      rendered_at: Time.current
    )

    prune
    frame
  end

  private

  def html
    # An unclaimed panel goes through the same pipeline, so its claim
    # code comes out at the same crispness as everything else.
    template = @device.claimed? ? "renders/dashboard" : "renders/setup"

    self.class.html(dashboard: @device.dashboard, device: @device, template: template)
  end

  def prune
    keep = @device.frames.recent.limit(KEEP_FRAMES).pluck(:id)
    @device.frames.where.not(id: keep).delete_all
  end
end
