require "test_helper"

class DashboardItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dashboard_item = dashboard_items(:one)
  end

  test "should get index" do
    get dashboard_items_url
    assert_response :success
  end

  test "should get new" do
    get new_dashboard_item_url
    assert_response :success
  end

  test "should create dashboard_item" do
    assert_difference("DashboardItem.count") do
      post dashboard_items_url, params: { dashboard_item: { col: @dashboard_item.col, col_span: @dashboard_item.col_span, dashboard_id: @dashboard_item.dashboard_id, kind: @dashboard_item.kind, position: @dashboard_item.position, row: @dashboard_item.row, row_span: @dashboard_item.row_span, settings: @dashboard_item.settings, title: @dashboard_item.title, view: @dashboard_item.view, visible: @dashboard_item.visible } }
    end

    assert_redirected_to builder_dashboard_url(@dashboard_item.dashboard)
  end

  test "should show dashboard_item" do
    get dashboard_item_url(@dashboard_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_dashboard_item_url(@dashboard_item)
    assert_response :success
  end

  test "should update dashboard_item" do
    patch dashboard_item_url(@dashboard_item), params: { dashboard_item: { col: @dashboard_item.col, col_span: @dashboard_item.col_span, dashboard_id: @dashboard_item.dashboard_id, kind: @dashboard_item.kind, position: @dashboard_item.position, row: @dashboard_item.row, row_span: @dashboard_item.row_span, settings: @dashboard_item.settings, title: @dashboard_item.title, view: @dashboard_item.view, visible: @dashboard_item.visible } }
    assert_redirected_to builder_dashboard_url(@dashboard_item.dashboard)
  end

  test "should destroy dashboard_item" do
    assert_difference("DashboardItem.count", -1) do
      delete dashboard_item_url(@dashboard_item)
    end

    assert_redirected_to builder_dashboard_url(@dashboard_item.dashboard)
  end

  test "reposition moves and resizes the item" do
    patch reposition_dashboard_item_url(@dashboard_item),
          params: { dashboard_item: { col: 3, row: 2, col_span: 2, row_span: 2 } },
          as: :json

    assert_response :success
    assert JSON.parse(response.body)["ok"]

    @dashboard_item.reload
    assert_equal [ 3, 2, 2, 2 ],
                 [ @dashboard_item.col, @dashboard_item.row,
                   @dashboard_item.col_span, @dashboard_item.row_span ]
  end

  test "reposition refuses a placement that leaves the grid" do
    before = @dashboard_item.slice(:col, :row, :col_span, :row_span)

    patch reposition_dashboard_item_url(@dashboard_item),
          params: { dashboard_item: { col: 6, row: 1, col_span: 4, row_span: 3 } },
          as: :json

    assert_response :unprocessable_content

    body = JSON.parse(response.body)
    assert_not body["ok"]
    assert_includes body["errors"].join(" "), "extends past the grid"
    assert_equal before, @dashboard_item.reload.slice(:col, :row, :col_span, :row_span)
  end

  test "create places the item in the first free slot" do
    dashboard = dashboards(:one)

    post dashboard_items_url,
         params: { dashboard_item: { dashboard_id: dashboard.id, kind: "clock",
                                     col_span: 2, row_span: 2, visible: true } }

    assert_redirected_to builder_dashboard_url(dashboard)

    item = DashboardItem.order(:id).last
    # Fixture :one holds cols 1-4 / rows 1-3, so the first 2x2 opening is
    # at column 5 on row 1.
    assert_equal [ 5, 1 ], [ item.col, item.row ]
  end

  test "create reports when nothing fits" do
    dashboard = dashboards(:one)

    assert_no_difference("DashboardItem.count") do
      post dashboard_items_url,
           params: { dashboard_item: { dashboard_id: dashboard.id, kind: "clock",
                                       col_span: 8, row_span: 8, visible: true } }
    end

    assert_redirected_to builder_dashboard_url(dashboard)
    assert_match(/No room/, flash[:alert])
  end

  test "edit renders the layouts and settings for the item's kind" do
    get edit_dashboard_item_url(@dashboard_item) # weather

    assert_response :success
    assert_select "select[name=?] option", "dashboard_item[view]", 3
    assert_select "option[value=?]", "forecast"
    assert_select "option[value=?]", "month", 0, "calendar layouts must not leak in"
    assert_select "input[name=?]", "dashboard_item[settings][day_count]"
  end

  test "edit previews another kind without saving it" do
    get edit_dashboard_item_url(@dashboard_item, kind: "calendar")

    assert_response :success
    assert_select "option[value=?]", "month"
    assert_select "input[name=?]", "dashboard_item[settings][show_times]"
    assert_equal "weather", @dashboard_item.reload.kind, "the preview must not persist"
  end

  test "edit ignores an unknown kind" do
    get edit_dashboard_item_url(@dashboard_item, kind: "Kernel")

    assert_response :success
    assert_select "option[value=?][selected]", "current"
  end

  test "the source select offers only the kind's provider type" do
    get edit_dashboard_item_url(@dashboard_item, kind: "news")

    assert_response :success
    assert_select "select[name=?] option", "dashboard_item[source_ids][]" do |options|
      names = options.map(&:text).reject(&:blank?)
      assert_includes names, sources(:three).name  # RSS
      assert_not_includes names, sources(:one).name # weather
      assert_not_includes names, sources(:two).name # iCal
    end
  end

  test "settings fields are styled by the form builder" do
    get edit_dashboard_item_url(dashboard_items(:two)) # calendar: show_times is on

    assert_select ".setting.form-check" do
      assert_select "input[type=hidden][name=?][value='0']", "dashboard_item[settings][show_times]"
      assert_select "input.form-check-input[type=checkbox][name=?][checked]", "dashboard_item[settings][show_times]"
      assert_select "label.form-check-label[for=?]", "dashboard_item_settings_show_times"
    end

    get edit_dashboard_item_url(@dashboard_item) # weather: day_count is a number

    assert_select "label[for=?]", "dashboard_item_settings_day_count"
    assert_select "input.form-control[type=number][id=?][name=?]",
                  "dashboard_item_settings_day_count", "dashboard_item[settings][day_count]"
  end

  test "a kind with no sources renders no source select" do
    get edit_dashboard_item_url(@dashboard_item, kind: "clock")

    assert_response :success
    assert_select "select[name=?]", "dashboard_item[source_ids][]", 0
  end

  test "settings round-trip through the form" do
    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "forecast", title: "Week",
                        settings: { "day_count" => "7", "hour_count" => "6" } }
    }

    assert_redirected_to builder_dashboard_url(@dashboard_item.dashboard)
    @dashboard_item.reload
    assert_equal "forecast", @dashboard_item.view
    assert_equal 7, @dashboard_item.setting("day_count")
  end

  test "a boolean setting can be switched off through the form" do
    item = dashboard_items(:two) # calendar, show_times defaults to true
    assert_equal true, item.setting("show_times")

    patch dashboard_item_url(item), params: {
      dashboard_item: { kind: "calendar", view: "today",
                        settings: { "show_times" => "0" } }
    }

    assert_redirected_to builder_dashboard_url(item.dashboard)
    assert_equal false, item.reload.setting("show_times")
  end

  test "an incompatible layout is rejected with an error" do
    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "month" }
    }

    assert_response :unprocessable_content
    assert_select "ul.errors li", /isn't available for Weather/
    assert_equal "current", @dashboard_item.reload.view
  end

  test "attaching two sources to a single-source kind is rejected" do
    second = Source.create!(
      name: "Other weather", refresh_seconds: 900,
      providable: WeatherProvider.new(latitude: 1, longitude: 2, units: "metric")
    )

    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "current",
                        source_ids: [ sources(:one).id, second.id ] }
    }

    assert_response :unprocessable_content
    assert_select "ul.errors li", /only one is allowed for Weather/
  end
end
