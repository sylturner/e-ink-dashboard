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
end
