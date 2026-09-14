require "test_helper"

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

  test "a png frame is served as it was sent" do
    device = devices(:two) # 800x480 png
    frame = device.frames.create!(data: white.to_png, format: "png")

    get device_last_frame_url(device)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal frame.data.b, response.body.b
  end

  test "an unchanged frame is revalidated with a 304" do
    @device.frames.create!(data: white.to_bmp, format: "bmp")

    get device_last_frame_url(@device)
    get device_last_frame_url(@device), headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
  end

  test "a 304 doesn't read the bitmap" do
    @device.frames.create!(data: white.to_bmp, format: "bmp")
    get device_last_frame_url(@device)
    etag = response.headers["ETag"]

    queries = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:sql] }, "sql.active_record") do
      get device_last_frame_url(@device), headers: { "If-None-Match" => etag }
    end

    assert_response :not_modified
    assert_empty queries.grep(/SELECT "frames"\.(\*|"data")/)
  end

  test "a device with no frame yet has nothing to show" do
    get device_last_frame_url(@device)
    assert_response :not_found

    get device_last_frame_url(Device.create!(name: "Fresh"))
    assert_response :not_found
  end

  # A panel's own check-in (Api::DisplaysController) records telemetry and
  # can compose a frame.
  test "looking at the last frame is not a check-in and renders nothing" do
    @device.frames.create!(data: white.to_bmp, format: "bmp")

    stub_method(FrameComposer, :call, raises: RuntimeError.new("should not compose")) do
      assert_no_changes -> { @device.reload.attributes.slice("last_seen_at", "battery_voltage", "refresh_requested_at") } do
        assert_no_difference "Frame.count" do
          get device_last_frame_url(@device), headers: { "Battery-Voltage" => "3.5", "Update-Source" => "button" }
        end
      end
    end

    assert_response :success
  end
end
