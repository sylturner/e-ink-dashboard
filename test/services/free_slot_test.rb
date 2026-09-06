require "test_helper"

class FreeSlotTest < ActiveSupport::TestCase
  setup do
    @dashboard = dashboards(:one) # 8x8, with fixture :one at cols 1-4 / rows 1-3
  end

  test "returns the first opening that fits" do
    assert_equal [ 5, 1 ], FreeSlot.find(@dashboard, 2, 2)
  end

  test "skips openings that are too narrow" do
    # Only four columns are clear on row 1, so a 5-wide tile drops to row 4.
    assert_equal [ 1, 4 ], FreeSlot.find(@dashboard, 5, 2)
  end

  test "returns nil when nothing fits" do
    assert_nil FreeSlot.find(@dashboard, 8, 8)
  end

  test "uses the whole grid when it is empty" do
    @dashboard.dashboard_items.destroy_all
    assert_equal [ 1, 1 ], FreeSlot.find(@dashboard.reload, 8, 8)
  end
end
