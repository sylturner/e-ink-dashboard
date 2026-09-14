require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  test "renders at its first device's size, or the default panel's without one" do
    dashboard = dashboards(:one)
    devices(:one).update!(width: 1200, height: 825)
    devices(:one).dashboards = [ dashboard ]

    assert_equal [ 1200, 825 ], dashboard.reload.screen_size
    assert_equal [ 800, 480 ], Dashboard.new.screen_size
  end

  test "deleting a dashboard keeps its panels' frames" do
    frame = frames(:one)

    dashboards(:one).destroy!

    assert_nil frame.reload.dashboard_id
  end
end
