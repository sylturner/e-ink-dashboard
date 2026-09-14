require "test_helper"

class Api::SetupsControllerTest < ActionDispatch::IntegrationTest
  MAC = "A4:CF:12:9B:0D:7E".freeze

  def set_up_panel(mac: MAC, headers: {})
    get api_setup_url, headers: { "ID" => mac }.compact.merge(headers)
  end

  test "a panel gets an API key and its claim code" do
    assert_difference "Device.count", 1 do
      set_up_panel(headers: { "FW-Version" => "1.6.9", "Model" => "og" })
    end

    assert_response :success
    device = Device.order(:id).last
    body = response.parsed_body

    assert_equal 200, body["status"]
    assert_equal device.token, body["api_key"]
    assert_equal device.claim_code, body["friendly_id"]
    assert_includes body["message"], device.claim_code
    assert_equal "a4:cf:12:9b:0d:7e", device.mac_address, "MAC is normalized"
    assert_equal "1.6.9", device.firmware_version
    assert_not_nil device.enrolled_at
  end

  test "the name defaults to the tail of the MAC" do
    set_up_panel
    assert_equal "Panel 0D7E", Device.order(:id).last.name
  end

  test "a TRMNL, which sends no size, is an 800x480 BMP panel on the app's schedule" do
    AppSetting.current.update!(refresh_seconds: 1200, night_refresh_seconds: 5400,
                               active_from_hour: 7, active_until_hour: 22)

    set_up_panel

    device = Device.order(:id).last
    assert_equal [ 800, 480, 1, "bmp" ],
                 [ device.width, device.height, device.bit_depth, device.image_format ]
    assert_equal [ 1200, 5400, 7, 22 ],
                 [ device.refresh_seconds, device.night_refresh_seconds,
                   device.active_from_hour, device.active_until_hour ]
    assert_nil device.time_zone
  end

  test "a panel at another size is sent PNG" do
    set_up_panel(headers: { "Width" => "960", "Height" => "540" })

    device = Device.order(:id).last
    assert_equal [ 960, 540, "png" ], [ device.width, device.height, device.image_format ]
  end

  # A panel retrying after a timeout must not pile up rows.
  test "setting up twice returns the same device and the same key" do
    set_up_panel
    first = Device.order(:id).last

    assert_no_difference "Device.count" do
      set_up_panel
    end

    assert_response :success
    assert_equal first.token, response.parsed_body["api_key"]
  end

  test "setting up again keeps the dashboard assignment and refreshes the firmware version" do
    set_up_panel
    device = Device.order(:id).last
    device.dashboards = [ dashboards(:one) ]

    set_up_panel(headers: { "FW-Version" => "1.7.0" })

    device.reload
    assert_equal [ dashboards(:one) ], device.dashboards.to_a
    assert_equal dashboards(:one), device.dashboard
    assert_equal "1.7.0", device.firmware_version
  end

  test "a missing MAC is not registered" do
    assert_no_difference "Device.count" do
      get api_setup_url
    end

    assert_response :not_found
  end

  test "a panel that can't be saved is reported rather than raising" do
    set_up_panel
    Device.order(:id).last.update_columns(dither: "bogus")

    set_up_panel

    assert_response :not_found
  end
end
