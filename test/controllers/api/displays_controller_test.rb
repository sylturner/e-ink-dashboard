require "test_helper"

class Api::DisplaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one) # 800x480 bmp, showing dashboard one

    # The newest frame is current. FrameComposer needs headless Chrome, so
    # it is stubbed to hand back the other one: which frame a check-in
    # points at shows whether it composed.
    @composed = @device.frames.create!(dashboard: dashboards(:one), data: bmp("\x00"), format: "bmp", rendered_at: 1.day.ago)
    @current  = @device.frames.create!(dashboard: dashboards(:one), data: bmp("\xFF"), format: "bmp")
  end

  def bmp(fill)
    Bitmap.new(width: 800, height: 480, rows: Array.new(480) { fill.b * 100 }).to_bmp
  end

  def check_in(device = @device, headers: {}, composer: { returns: @composed })
    stub_method(FrameComposer, :call, **composer) do
      get api_display_url, headers: { "ID" => device.mac_address.to_s, "Access-Token" => device.token }.merge(headers)
    end

    assert_response :success
    response.parsed_body
  end

  test "an unknown API key is told to set up again" do
    get api_display_url, headers: { "ID" => "aa:bb:cc:dd:ee:ff", "Access-Token" => "nope" }

    assert_response :success
    assert_equal({ "status" => 500 }, response.parsed_body)
  end

  test "a panel is pointed at its current frame and told when to come back" do
    body = check_in

    assert_equal 0, body["status"]
    assert_equal api_image_url(@current, format: "bmp"), body["image_url"]
    assert_equal @current.filename, body["filename"]
    assert_equal @device.sleep_seconds, body["refresh_rate"]
    assert_equal "restart_playlist", body["special_function"]
    assert_nil body["action"]
    assert_equal false, body["reset_firmware"]
    assert_equal false, body["update_firmware"]
  end

  test "the panel's report is recorded" do
    freeze_time do
      check_in(headers: { "Battery-Voltage" => "3.75", "RSSI" => "-60", "FW-Version" => "1.6.9" })

      @device.reload
      assert_equal Time.current, @device.last_seen_at
      assert_equal [ 3.75, 50, -60, "1.6.9" ],
                   [ @device.battery_voltage.to_f, @device.battery_percent, @device.wifi_rssi, @device.firmware_version ]
    end
  end

  test "a panel's own charge reading wins over the estimate" do
    check_in(headers: { "Battery-Voltage" => "3.75", "Percent-Charged" => "80" })

    assert_equal 80, @device.reload.battery_percent
  end

  test "a button press renders a fresh frame" do
    body = check_in(headers: { "Update-Source" => "button" })

    assert_equal @composed.filename, body["filename"]
  end

  test "a requested refresh renders a fresh frame" do
    @device.request_refresh!

    body = check_in

    assert_equal @composed.filename, body["filename"]
    assert_nil @device.reload.refresh_requested_at
  end

  # Sent as the server hands it over: a special_function header arrives
  # as HTTP_SPECIAL_FUNCTION. Naming it "special_function" here would
  # pass even when a real panel's press was ignored.
  test "the special function moves the panel to its next dashboard" do
    before = @device.dashboard_id

    body = check_in(headers: { "HTTP_SPECIAL_FUNCTION" => "true" })

    assert_not_equal before, @device.reload.dashboard_id
    assert_equal "restart_playlist", body["action"]
    assert_equal @composed.filename, body["filename"]
  end

  test "a render that fails falls back to the last frame" do
    body = check_in(headers: { "Update-Source" => "button" }, composer: { raises: RuntimeError.new("Chrome is gone") })

    assert_equal 0, body["status"]
    assert_equal @current.filename, body["filename"]
  end

  test "with nothing to show yet, the panel is asked back soon" do
    device = Device.create!(name: "Fresh")

    body = check_in(device, composer: { raises: RuntimeError.new("Chrome is gone") })

    assert_equal({ "status" => 202, "refresh_rate" => Device::UNCLAIMED_SLEEP }, body)
  end
end
