require "test_helper"

class DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one)
  end

  test "should get index" do
    get devices_url
    assert_response :success
  end

  test "should get new" do
    get new_device_url
    assert_response :success
  end

  test "should create device" do
    assert_difference("Device.count") do
      post devices_url, params: { device: { active_from_hour: @device.active_from_hour, active_until_hour: @device.active_until_hour, battery_percent: @device.battery_percent, battery_voltage: @device.battery_voltage, bit_depth: @device.bit_depth, dashboard_id: @device.dashboard_id, firmware_version: @device.firmware_version, height: @device.height, image_format: @device.image_format, last_seen_at: @device.last_seen_at, name: @device.name, night_refresh_seconds: @device.night_refresh_seconds, refresh_requested_at: @device.refresh_requested_at, refresh_seconds: @device.refresh_seconds, rotation: @device.rotation, time_zone: @device.time_zone, width: @device.width, wifi_rssi: @device.wifi_rssi } }
    end

    assert_redirected_to device_url(Device.last)
  end

  test "should show device" do
    get device_url(@device)
    assert_response :success
  end

  test "should get edit" do
    get edit_device_url(@device)
    assert_response :success
  end

  test "should update device" do
    patch device_url(@device), params: { device: { active_from_hour: @device.active_from_hour, active_until_hour: @device.active_until_hour, battery_percent: @device.battery_percent, battery_voltage: @device.battery_voltage, bit_depth: @device.bit_depth, dashboard_id: @device.dashboard_id, firmware_version: @device.firmware_version, height: @device.height, image_format: @device.image_format, last_seen_at: @device.last_seen_at, name: @device.name, night_refresh_seconds: @device.night_refresh_seconds, refresh_requested_at: @device.refresh_requested_at, refresh_seconds: @device.refresh_seconds, rotation: @device.rotation, time_zone: @device.time_zone, width: @device.width, wifi_rssi: @device.wifi_rssi } }
    assert_redirected_to device_url(@device)
  end

  test "should destroy device" do
    assert_difference("Device.count", -1) do
      delete device_url(@device)
    end

    assert_redirected_to devices_url
  end

  test "unclaimed devices appear as waiting to be set up, with their code" do
    pending = Device.enroll!(mac: "a4:cf:12:9b:0d:7e")

    get devices_url

    assert_response :success
    assert_select "section.pending .claim-row", 1
    assert_select "section.pending .code", pending.claim_code
    assert_select "section.pending", /#{pending.mac_address}/
  end

  test "claimed devices are not listed as pending" do
    devices(:one).dashboards = [ dashboards(:one) ]
    Device.where.not(id: devices(:one).id).find_each { |d| d.dashboards = [ dashboards(:one) ] }

    get devices_url

    assert_select "section.pending", 0
  end

  # The claim form must create an assignment: setting dashboard_id alone
  # is reverted by Device#sync_active_dashboard.
  test "claiming a pending device from the index assigns it a dashboard" do
    pending = Device.enroll!(mac: "a4:cf:12:9b:0d:7e")
    assert_not pending.claimed?

    assert_difference "DeviceDashboard.count", 1 do
      post device_dashboards_url, params: {
        context: "devices",
        device_dashboard: { device_id: pending.id, dashboard_id: dashboards(:one).id }
      }
    end

    assert_redirected_to devices_path
    pending.reload
    assert pending.claimed?
    assert_equal dashboards(:one), pending.dashboard
  end

  test "a claimed device drops out of the pending list" do
    pending = Device.enroll!(mac: "a4:cf:12:9b:0d:7e")
    pending.dashboards = [ dashboards(:one) ]

    get devices_url

    assert_select ".claim-row .code", { text: pending.claim_code, count: 0 }
  end
end
