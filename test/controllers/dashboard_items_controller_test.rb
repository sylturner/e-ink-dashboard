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

    assert_redirected_to dashboard_item_url(DashboardItem.last)
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
    assert_redirected_to dashboard_item_url(@dashboard_item)
  end

  test "should destroy dashboard_item" do
    assert_difference("DashboardItem.count", -1) do
      delete dashboard_item_url(@dashboard_item)
    end

    assert_redirected_to dashboard_items_url
  end
end
