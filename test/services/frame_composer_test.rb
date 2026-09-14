require "test_helper"
require "vips"

class FrameComposerTest < ActiveSupport::TestCase
  test "a frame remembers the dashboard it was rendered from" do
    device = devices(:one)
    device.update_columns(width: 16, height: 8)
    png = Vips::Image.black(16, 8).write_to_buffer(".png")

    frame = stub_method(BrowserPool, :capture, returns: png) { FrameComposer.call(device) }

    assert_equal dashboards(:one), frame.dashboard
  end
end
