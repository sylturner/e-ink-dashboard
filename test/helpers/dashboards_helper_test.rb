require "test_helper"

class DashboardsHelperTest < ActionView::TestCase
  test "a tile's title is its header, or the component's name without one" do
    assert_equal "Family", builder_tile_title(DashboardItem.new(kind: "calendar", title: "Family"))
    assert_equal "Weather", builder_tile_title(DashboardItem.new(kind: "weather", title: ""))
  end

  test "a tile is named by its title, component and layout, without repeats" do
    item = dashboard_items(:two) # headed "Calendar": a calendar in the week layout

    assert_equal "Calendar, This week", builder_tile_name(item)
  end

  test "a custom header comes before the component and layout" do
    item = DashboardItem.new(kind: "calendar", view: "next_days", title: "Family")

    assert_equal "Family, Calendar, Next X days", builder_tile_name(item)
  end

  # grid_controller#describe rebuilds this label in JS after a move.
  test "the label adds where the tile sits on the grid" do
    item = dashboard_items(:one) # Weather, current, column 1, row 1, 4 by 3

    assert_equal "Weather, Right now, column 1, row 1, 4 by 3", builder_tile_label(item)
  end
end
