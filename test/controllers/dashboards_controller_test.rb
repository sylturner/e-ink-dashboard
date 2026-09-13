require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dashboard = dashboards(:one)
  end

  test "the index shows each dashboard as a card with its thumbnail" do
    get dashboards_url

    assert_response :success
    assert_select "header.page-hero a[href=?]", new_dashboard_path
    assert_select "#dashboards > li > .card", Dashboard.count
    assert_select "#dashboard_#{@dashboard.id}" do
      assert_select "img.dashboard-thumbnail[src=?][loading=lazy][width][height]",
                    dashboard_thumbnail_path(@dashboard, format: :png)
      assert_select "img[alt=?]", "Preview showing Weather"
      assert_select "a.stretched-link[href=?]", builder_dashboard_path(@dashboard), @dashboard.name
      assert_select ".card-footer a[href=?]", edit_dashboard_path(@dashboard), "Settings for #{@dashboard.name}"
      assert_select ".card-footer form[action=?] button", dashboard_path(@dashboard), "Delete #{@dashboard.name}"
    end
  end

  test "with no dashboards the index offers to create one" do
    Dashboard.destroy_all

    get dashboards_url

    assert_select "#dashboards", 0
    assert_select "main a[href=?]", new_dashboard_path, 2
  end

  test "should get new" do
    get new_dashboard_url
    assert_response :success
  end

  test "should create dashboard" do
    assert_difference("Dashboard.count") do
      post dashboards_url, params: { dashboard: { grid_columns: @dashboard.grid_columns, grid_rows: @dashboard.grid_rows, name: @dashboard.name, theme: @dashboard.theme } }
    end

    assert_redirected_to dashboard_url(Dashboard.last)
  end

  test "should show dashboard" do
    get dashboard_url(@dashboard)
    assert_response :success
  end

  test "should get builder" do
    get builder_dashboard_url(@dashboard)
    assert_response :success
  end

  test "should get edit" do
    get edit_dashboard_url(@dashboard)
    assert_response :success
  end

  test "should update dashboard" do
    patch dashboard_url(@dashboard), params: { dashboard: { grid_columns: @dashboard.grid_columns, grid_rows: @dashboard.grid_rows, name: @dashboard.name, theme: @dashboard.theme } }
    assert_redirected_to dashboard_url(@dashboard)
  end

  test "update from the builder returns to the builder" do
    patch dashboard_url(@dashboard),
          params: { from_builder: "1", dashboard: { theme: "night" } }
    assert_redirected_to builder_dashboard_url(@dashboard)
    assert_equal "night", @dashboard.reload.theme
  end

  test "should reject an unknown theme" do
    patch dashboard_url(@dashboard), params: { dashboard: { theme: "neon" } }
    assert_response :unprocessable_content
  end

  test "should destroy dashboard" do
    assert_difference("Dashboard.count", -1) do
      delete dashboard_url(@dashboard)
    end

    assert_redirected_to dashboards_url
  end

  test "the builder links to each device's bitmap under the preview" do
    device = devices(:one)
    device.dashboards = [ @dashboard ]

    get builder_dashboard_url(@dashboard)

    assert_response :success
    assert_select ".builder-preview .device-list li", 1
    assert_select ".device-list a[href=?][target=_blank]",
                  device_frame_path(token: device.token), device.name.to_s + " bitmap"
    assert_select ".device-list a[href=?]", device_path(device)
  end

  test "every assigned device gets its own link" do
    devices(:one).dashboards = [ @dashboard ]
    devices(:two).dashboards = [ @dashboard ]

    get builder_dashboard_url(@dashboard)

    assert_select ".device-list li", 2
    [ devices(:one), devices(:two) ].each do |device|
      assert_select ".device-list a[href=?]", device_frame_path(token: device.token)
    end
  end

  test "a dashboard with no device says so and offers to assign one" do
    @dashboard.device_dashboards.destroy_all

    get builder_dashboard_url(@dashboard)

    assert_response :success
    assert_select ".device-list", 0
    assert_select ".device-previews", /No device is assigned/
    assert_select "form.assign-device select[name=?] option", "device_dashboard[device_id]",
                  Device.count
  end

  test "the builder can assign this dashboard to a device" do
    @dashboard.device_dashboards.destroy_all
    device = devices(:one)
    assert_nil device.reload.dashboard, "cleared by removing the assignment"

    assert_difference "DeviceDashboard.count", 1 do
      post device_dashboards_url, params: {
        context: "builder",
        device_dashboard: { device_id: device.id, dashboard_id: @dashboard.id }
      }
    end

    assert_redirected_to builder_dashboard_path(@dashboard)
    assert_includes device.reload.dashboards, @dashboard
    assert_equal @dashboard, device.dashboard, "the first assignment becomes the active one"
  end

  test "the builder can unassign a device" do
    device = devices(:one)
    device.dashboards = [ @dashboard ]
    assignment = device.device_dashboards.find_by!(dashboard: @dashboard)

    assert_difference "DeviceDashboard.count", -1 do
      delete device_dashboard_url(assignment), params: { context: "builder" }
    end

    assert_redirected_to builder_dashboard_path(@dashboard)
    assert_empty device.reload.dashboards
    assert_nil device.dashboard, "nothing left to show"
  end

  test "assigning the same dashboard twice is refused" do
    device = devices(:one)
    device.dashboards = [ @dashboard ]

    assert_no_difference "DeviceDashboard.count" do
      post device_dashboards_url, params: {
        context: "builder",
        device_dashboard: { device_id: device.id, dashboard_id: @dashboard.id }
      }
    end

    assert_redirected_to builder_dashboard_path(@dashboard)
    assert_match(/already been taken/i, flash[:alert])
  end

  # WCAG 2.1.1 and 4.1.3: tiles can be reached and selected without a
  # pointer, say where they sit, and saves are announced.
  test "builder tiles are keyboard buttons that announce their position" do
    dashboard = dashboards(:two)
    item = dashboard_items(:two)

    get builder_dashboard_url(dashboard)

    assert_select ".tile[role=button][tabindex='0'][aria-pressed=false][data-id=?]", item.id.to_s do |tiles|
      assert_match(/, column #{item.col}, row #{item.row}, #{item.col_span} by #{item.row_span}\z/,
                   tiles.first["aria-label"])
    end
    assert_select ".tile .tile-label[aria-hidden=true]"
    assert_select ".builder-status[role=status]"
  end

  # WCAG 2.5.7: every drag has a single-click alternative.
  test "the builder offers move and resize buttons as an alternative to dragging" do
    get builder_dashboard_url(dashboards(:two))

    assert_select ".builder-movers[role=group][aria-label]" do
      assert_select "button[type=button][disabled][data-action=?]", "grid#moveBy", 8
      [ "Move left", "Move right", "Move up", "Move down", "Narrower", "Wider", "Shorter", "Taller" ].each do |label|
        assert_select "button", label
      end
    end
  end

  test "each tile carries the URLs the grid controller loads and saves it with" do
    item = dashboard_items(:two)

    get builder_dashboard_url(dashboards(:two))

    assert_select ".tile[data-id=?][data-edit-url=?][data-reposition-url=?]",
                  item.id.to_s, edit_dashboard_item_path(item), reposition_dashboard_item_path(item)
  end

  # The inspector loads a second dashboard_item form beside the palette.
  test "the add-a-tile form's ids can't collide with the tile inspector's" do
    get builder_dashboard_url(@dashboard)

    assert_select ".palette label[for=?]", "palette_dashboard_item_kind"
    assert_select ".palette select#palette_dashboard_item_kind"
    assert_select "#dashboard_item_kind", 0
  end

  test "a refused assignment is shown on the builder" do
    device = devices(:one)
    device.dashboards = [ @dashboard ]

    post device_dashboards_url, params: {
      context: "builder",
      device_dashboard: { device_id: device.id, dashboard_id: @dashboard.id }
    }
    follow_redirect!

    assert_select ".alert.alert-danger[role=alert]", /already been taken/i
  end

  test "only unassigned devices are offered" do
    devices(:one).dashboards = [ @dashboard ]

    get builder_dashboard_url(@dashboard)

    assert_select "form.assign-device option" do |options|
      values = options.map { |o| o["value"].to_i }
      assert_not_includes values, devices(:one).id
      assert_includes values, devices(:two).id
    end
  end
end
