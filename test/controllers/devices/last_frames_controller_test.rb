require "test_helper"
require "vips"

class Devices::LastFramesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one) # 800x480 bmp; its fixture frame has no data
  end

  def white(width = 800, height = 480)
    Bitmap.new(width:, height:, rows: Array.new(height) { "\xFF".b * ((width + 7) / 8) })
  end

  test "a bmp frame is served as it was sent" do
    frame = @device.frames.create!(data: white.to_bmp, format: "bmp")

    get device_last_frame_url(@device)

    assert_response :success
    assert_equal "image/bmp", response.media_type
    assert_equal frame.data.b, response.body.b
  end

  test "a raw frame is drawn to a PNG, since browsers can't show one" do
    device = devices(:two) # 800x480 raw
    device.frames.create!(data: white.to_raw, format: "raw")

    get device_last_frame_url(device)

    assert_response :success
    assert_equal "image/png", response.media_type
    image = Vips::Image.new_from_buffer(response.body, "")
    assert_equal [ 800, 480 ], [ image.width, image.height ]
    assert_equal 255, image.min
  end

  test "a raw frame that no longer fits the panel's size isn't shown" do
    device = devices(:two)
    device.frames.create!(data: white.to_raw, format: "raw")
    device.update_columns(width: 640)

    get device_last_frame_url(device)

    assert_response :not_found
  end

  test "an unchanged frame is revalidated with a 304" do
    @device.frames.create!(data: white.to_bmp, format: "bmp")

    get device_last_frame_url(@device)
    get device_last_frame_url(@device), headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
  end

  test "a device with no frame yet has nothing to show" do
    get device_last_frame_url(@device)
    assert_response :not_found

    get device_last_frame_url(Device.create!(name: "Fresh"))
    assert_response :not_found
  end

  # The panel's own frame URL records a check-in and can compose a frame.
  test "looking at the last frame is not a check-in and renders nothing" do
    @device.frames.create!(data: white.to_bmp, format: "bmp")

    stub_method(FrameComposer, :call, raises: RuntimeError.new("should not compose")) do
      assert_no_changes -> { @device.reload.attributes.slice("last_seen_at", "battery_percent", "refresh_requested_at") } do
        assert_no_difference "Frame.count" do
          get device_last_frame_url(@device), headers: { "X-Battery-Percent" => "5", "X-Refresh" => "force" }
        end
      end
    end

    assert_response :success
  end

  test "the panels' frame route is not taken by the last frame's" do
    assert_recognizes({ controller: "frames", action: "show", token: "kitchen_token_fixture" },
                      "/devices/kitchen_token_fixture/frame")
    assert_recognizes({ controller: "devices/last_frames", action: "show", device_id: "1" },
                      "/devices/1/last_frame")
  end
end
