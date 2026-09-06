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
end
