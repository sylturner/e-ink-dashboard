require "test_helper"

class EnrollmentsControllerTest < ActionDispatch::IntegrationTest
  MAC = "A4:CF:12:9B:0D:7E".freeze

  def enroll(mac: MAC, headers: {})
    post enroll_devices_url, headers: { "X-Device-Mac" => mac }.compact.merge(headers)
  end

  test "a device gets a token back" do
    assert_difference "Device.count", 1 do
      enroll
    end

    assert_response :success
    assert_equal "text/plain", response.media_type

    device = Device.order(:id).last
    assert_equal response.body, device.token
    assert_equal "a4:cf:12:9b:0d:7e", device.mac_address, "MAC is normalized"
    assert_not_nil device.enrolled_at
    assert_match(/\A[A-Z2-9]{4}\z/, device.claim_code)
  end

  test "the name defaults to the tail of the MAC" do
    enroll
    assert_equal "Panel 0D7E", Device.order(:id).last.name
  end

  test "geometry comes from the headers, with defaults" do
    enroll(headers: {
      "X-Device-Width" => "960", "X-Device-Height" => "540",
      "X-Device-Bit-Depth" => "2", "X-Device-Format" => "raw",
      "X-Firmware-Version" => "2.1.0"
    })

    device = Device.order(:id).last
    assert_equal [ 960, 540, 2, "raw", "2.1.0" ],
                 [ device.width, device.height, device.bit_depth,
                   device.image_format, device.firmware_version ]
  end

  test "defaults apply when the firmware sends no geometry" do
    enroll

    device = Device.order(:id).last
    assert_equal [ 800, 480, 1, "bmp" ],
                 [ device.width, device.height, device.bit_depth, device.image_format ]
    assert_equal 900, device.refresh_seconds
  end

  # A device retrying after a timeout must not pile up rows.
  test "enrolling twice returns the same device and the same token" do
    enroll
    first = Device.order(:id).last

    assert_no_difference "Device.count" do
      enroll
    end

    assert_response :success
    assert_equal first.token, response.body
  end

  test "re-enrolling keeps the dashboard assignment and refreshes geometry" do
    enroll
    device = Device.order(:id).last
    device.dashboards = [ dashboards(:one) ]

    enroll(headers: { "X-Device-Bit-Depth" => "4", "X-Firmware-Version" => "3.0.0" })

    device.reload
    assert_equal [ dashboards(:one) ], device.dashboards.to_a
    assert_equal dashboards(:one), device.dashboard
    assert_equal 4, device.bit_depth
    assert_equal "3.0.0", device.firmware_version
  end




  test "a missing MAC is a bad request" do
    assert_no_difference "Device.count" do
      post enroll_devices_url
    end

    assert_response :bad_request
  end

  test "an unusable device is reported rather than raising" do
    assert_no_difference "Device.count" do
      enroll(headers: { "X-Device-Bit-Depth" => "3" }) # only 1, 2 and 4 are valid
    end

    assert_response :unprocessable_content
  end
end
