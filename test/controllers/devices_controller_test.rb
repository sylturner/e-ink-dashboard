require "test_helper"

class DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one) # Kitchen panel, showing the Kitchen dashboard
  end

  test "the index shows each panel with a dashboard as a card" do
    get devices_url

    assert_response :success
    assert_select "header.page-hero a[href=?]", new_device_path
    assert_select "#devices > li > .card", Device.where.not(dashboard_id: nil).count
    assert_select "#device_#{@device.id}" do
      assert_select "a.stretched-link[href=?]", edit_device_path(@device), @device.name
      assert_select ".card-text", "Showing #{@device.dashboard.name}"
      assert_select ".panel-placeholder", /No frame yet/
      assert_select ".card-footer form[action=?] button", refresh_device_path(@device), "Refresh #{@device.name} on next wake"
      assert_select ".card-footer form[action=?] button", device_path(@device), "Delete #{@device.name}"
    end
  end

  # The token is the only credential on the panel's frame URL.
  test "the index doesn't show device tokens" do
    get devices_url

    Device.find_each { |device| assert_no_match device.token, response.body }
  end

  test "a card with a frame shows it, from the read-only last frame route" do
    @device.frames.create!(data: Bitmap.new(width: 8, height: 1, rows: [ "\xFF".b ]).to_bmp, format: "bmp")

    get devices_url

    assert_select "#device_#{@device.id} img.panel-thumbnail[src=?][alt=?][width='800'][height='480'][loading=lazy]",
                  device_last_frame_path(@device), "The last frame sent to #{@device.name}"
  end

  test "with no devices at all the index says how panels arrive" do
    Device.destroy_all

    get devices_url

    assert_select "#devices, section.pending", 0
    assert_select "main a[href=?]", new_device_path, 2
  end

  test "unclaimed devices appear as waiting to be set up, with their code" do
    pending = Device.enroll!(mac: "a4:cf:12:9b:0d:7e")

    get devices_url

    assert_response :success
    assert_select "section.pending .claim-row", 1
    assert_select "section.pending .code", pending.claim_code
    assert_select "section.pending", /#{pending.mac_address}/
    assert_select "section.pending a[href=?]", edit_device_path(pending), pending.name
    assert_select "#devices #device_#{pending.id}", 0
  end

  # Every row used to render the same ids, with an unlabeled select.
  test "each claim row's select is labeled and has its own id" do
    first  = Device.enroll!(mac: "a4:cf:12:9b:0d:7e")
    second = Device.enroll!(mac: "a4:cf:12:9b:0d:7f")

    get devices_url

    [ first, second ].each do |device|
      id = "claim_device_#{device.id}_device_dashboard_dashboard_id"
      assert_select "label[for=?]", id, "Dashboard for #{device.name}"
      assert_select "select##{id}[required]"
      assert_select ".claim-row button[type=submit]", "Assign to #{device.name}"
    end
    ids = css_select("[id]").map { it["id"] }
    assert_equal ids.uniq, ids, "duplicate ids on the page"
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

  # The devices pages used to render only the notice, so a refused claim
  # redirected back with no explanation.
  test "a refused claim says why on the devices page" do
    device = devices(:one)
    device.dashboards = [ dashboards(:one) ]

    post device_dashboards_url, params: {
      context: "devices",
      device_dashboard: { device_id: device.id, dashboard_id: dashboards(:one).id }
    }
    follow_redirect!

    assert_select ".alert.alert-danger", /already been taken/i
  end

  test "a claimed device drops out of the pending list" do
    pending = Device.enroll!(mac: "a4:cf:12:9b:0d:7e")
    pending.dashboards = [ dashboards(:one) ]

    get devices_url

    assert_select ".claim-row .code", { text: pending.claim_code, count: 0 }
  end

  test "new is the settings card on its own" do
    get new_device_url

    assert_response :success
    assert_select "h1", "New device"
    assert_select ".device-settings form[action=?]", devices_path do
      assert_select "select[name=?] option", "device[bit_depth]", Device::BIT_DEPTHS.size
      assert_select "select[name=?] option", "device[active_until_hour]", 24
      assert_select "input[type=submit][value=?]", "Create device"
    end
    assert_select ".device-status, .device-dashboards", 0
  end

  test "a new device starts on the app's schedule and time zone" do
    AppSetting.current.update!(refresh_seconds: 1200, active_from_hour: 8)

    get new_device_url

    assert_select "input[name=?][value='1200']", "device[refresh_seconds]"
    assert_select "select[name=?] option[selected][value='8']", "device[active_from_hour]"
    # Nothing selected, so the first choice -- the app's zone -- shows.
    assert_select "select[name=?] option:first-child[value='']", "device[time_zone]", "App time zone (Etc/UTC)"
    assert_select "select[name=?] option[selected]", "device[time_zone]", 0
  end

  test "creating a device opens its page" do
    assert_difference("Device.count") do
      post devices_url, params: { device: { name: "Hallway", width: 800, height: 480, bit_depth: 1,
                                            image_format: "bmp", rotation: 0, dither: "none" } }
    end

    assert_redirected_to edit_device_url(Device.last)
  end

  test "a rejected new device comes back with its errors" do
    assert_no_difference("Device.count") do
      post devices_url, params: { device: { name: "", time_zone: "Nowhere/Special" } }
    end

    assert_response :unprocessable_content
    assert_select ".device-settings ul.errors li", "Name can't be blank"
    assert_select "select.is-invalid[name=?]", "device[time_zone]"
  end

  test "edit is the device's page, with its status, dashboards and settings" do
    get edit_device_url(@device)

    assert_response :success
    assert_select "h1", @device.name
    assert_select ".breadcrumb a[href=?]", devices_path
    assert_select ".device-status" do
      assert_select "form[action=?] button", refresh_device_path(@device), "Refresh on next wake"
      assert_select ".panel-placeholder", /No frame yet/
      assert_select "dd", /84% \(3.91 V\)/
      assert_select "dd", /Good \(-62 dBm\)/
      assert_select "a[href=?][target=_blank][aria-describedby=?]", device_frame_path(token: @device.token), "live-bitmap-hint"
    end
    assert_select ".device-assignments li", 1 do
      assert_select "a[href=?]", edit_dashboard_path(dashboards(:one))
      assert_select ".badge", "Showing"
      assert_select "form[action=?] button", device_dashboard_path(device_dashboards(:one)), "Unassign #{dashboards(:one).name}"
    end
    assert_select "form.assign-dashboard select[name=?] option", "device_dashboard[dashboard_id]", Dashboard.count - 1
    assert_select ".device-settings form[action=?]", device_path(@device) do
      assert_select "input[name=?][value=?]", "device[name]", @device.name
      assert_select "input[type=submit][value=?]", "Save device"
      assert_select "form[action=?] button", device_path(@device), "Delete device"
    end
  end

  test "what the panel reports isn't editable" do
    get edit_device_url(@device)

    %w[last_seen_at battery_percent battery_voltage wifi_rssi firmware_version refresh_requested_at dashboard_ids].each do |field|
      assert_select "[name^=?]", "device[#{field}]", 0
    end
  end

  test "a device's settings hints are tied to their fields" do
    get edit_device_url(@device)

    assert_select "select[name=?][aria-describedby=?]", "device[dither]", "device_dither_hint"
    assert_select ".form-text#device_dither_hint"
    assert_select "input[name=?][aria-describedby=?]", "device[night_refresh_seconds]", "device_refresh_seconds_hint"
    assert_select "select[name=?][aria-describedby=?]", "device[time_zone]", "device_time_zone_hint"
  end

  test "saving the settings returns to the page and asks for a fresh frame" do
    @device.update_columns(refresh_requested_at: nil)

    patch device_url(@device), params: { device: { dither: "none", time_zone: "America/Chicago" } }

    assert_redirected_to edit_device_url(@device)
    @device.reload
    assert_equal "none", @device.dither
    assert_equal "America/Chicago", @device.time_zone
    assert_not_nil @device.refresh_requested_at
  end

  test "a rename or schedule change doesn't ask for a fresh frame" do
    @device.update_columns(refresh_requested_at: nil)

    patch device_url(@device), params: { device: { name: "Kitchen wall", refresh_seconds: 900, active_from_hour: 7 } }

    assert_redirected_to edit_device_url(@device)
    assert_equal [ "Kitchen wall", 900, 7 ], @device.reload.attributes.values_at("name", "refresh_seconds", "active_from_hour")
    assert_nil @device.refresh_requested_at
  end

  test "the sleep hint gives the longest sleep in words" do
    get edit_device_url(@device)

    assert_select "#device_refresh_seconds_hint", /21600 seconds \(about 6 hours\)/
  end

  # Hours weren't validated before, so a saved one can be out of range.
  test "a saved hour outside the range is shown as it is, not replaced" do
    @device.update_columns(active_until_hour: 0)

    get edit_device_url(@device)

    assert_select "select[name=?] option[selected]", "device[active_until_hour]", "00:00"
  end

  test "with no dashboards at all the device page offers to create one" do
    Dashboard.destroy_all

    get edit_device_url(@device)

    assert_select ".device-dashboards a[href=?]", new_dashboard_path
    assert_select ".device-dashboards form.assign-dashboard", 0
  end

  test "with every dashboard assigned the device page says so" do
    @device.dashboards = Dashboard.all

    get edit_device_url(@device)

    assert_select ".device-dashboards", /Every dashboard is already assigned/
    assert_select ".device-dashboards a[href=?]", new_dashboard_path, 0
  end

  test "telemetry posted to the form is ignored" do
    patch device_url(@device), params: { device: { name: @device.name, battery_percent: 1, wifi_rssi: -99,
                                                    firmware_version: "9.9.9", last_seen_at: "2020-01-01 00:00" } }

    assert_redirected_to edit_device_url(@device)
    @device.reload
    assert_equal [ 84, -62, "1.0.0" ], [ @device.battery_percent, @device.wifi_rssi, @device.firmware_version ]
    assert_equal Time.zone.parse("2026-09-05 20:01:00"), @device.last_seen_at
  end

  test "a rejected update shows its errors, with the page drawn from what is saved" do
    patch device_url(@device), params: { device: { name: "", time_zone: "Nowhere/Special" } }

    assert_response :unprocessable_content
    assert_select "h1", @device.name
    assert_select ".device-assignments li", 1
    assert_select "input.is-invalid[name=?]", "device[name]"
    assert_select "select.is-invalid[name=?] ~ .invalid-feedback", "device[time_zone]", "Time zone isn't a time zone name"
  end

  test "the dashboards card switches the panel to another of its dashboards" do
    @device.dashboards = [ dashboards(:one), dashboards(:two) ]
    @device.update_columns(refresh_requested_at: nil)

    get edit_device_url(@device)
    assert_select ".device-assignments form[action=?]", device_path(@device), 1 do
      assert_select "input[name=?][value=?]", "device[dashboard_id]", dashboards(:two).id.to_s
      assert_select "button", "Switch to #{dashboards(:two).name}"
    end

    patch device_url(@device), params: { device: { dashboard_id: dashboards(:two).id } }

    assert_redirected_to edit_device_url(@device)
    assert_equal "Kitchen panel will show Office when it next wakes.", flash[:notice]
    assert_equal dashboards(:two), @device.reload.dashboard
    assert_not_nil @device.refresh_requested_at
  end

  test "assigning and unassigning from the device page return to it" do
    post device_dashboards_url, params: { device_dashboard: { device_id: @device.id, dashboard_id: dashboards(:two).id } }
    assert_redirected_to edit_device_path(@device)

    delete device_dashboard_url(device_dashboards(:one))
    assert_redirected_to edit_device_path(@device)
    assert_equal [ dashboards(:two) ], @device.reload.dashboards
  end

  test "refresh on next wake asks for a fresh frame" do
    @device.update_columns(refresh_requested_at: nil)

    post refresh_device_url(@device)

    assert_redirected_to edit_device_url(@device)
    assert_not_nil @device.reload.refresh_requested_at
  end

  test "should destroy device" do
    assert_difference("Device.count", -1) do
      delete device_url(@device)
    end

    assert_redirected_to devices_url
  end

  test "old show links land on the device's page" do
    get "/devices/#{@device.id}"

    assert_redirected_to edit_device_path(@device)
  end
end
