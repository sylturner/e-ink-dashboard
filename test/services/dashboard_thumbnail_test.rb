require "test_helper"

class DashboardThumbnailTest < ActiveSupport::TestCase
  setup do
    @dashboard = dashboards(:one)
  end

  test "the digest holds while the render is unchanged and moves when it changes" do
    travel_to Time.zone.parse("2026-09-12 09:00") do
      digest = DashboardThumbnail.new(@dashboard).digest
      assert_equal digest, DashboardThumbnail.new(@dashboard).digest

      @dashboard.update!(theme: "night")
      assert_not_equal digest, DashboardThumbnail.new(@dashboard).digest
    end
  end

  test "the PNG is the headless Chrome capture" do
    stub_method(BrowserPool, :capture, returns: "captured") do
      assert_equal "captured", DashboardThumbnail.new(@dashboard).png
    end
  end
end
