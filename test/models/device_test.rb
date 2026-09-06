require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  setup do
    @device = devices(:one)
    @kitchen = dashboards(:one)
    @office  = dashboards(:two)
  end

  test "a device can be assigned several dashboards" do
    @device.dashboards = [ @kitchen, @office ]

    assert_equal [ @kitchen, @office ].sort_by(&:id),
                 @device.reload.dashboards.sort_by(&:id)
    assert_equal 2, @device.device_dashboards.count
  end

  test "a dashboard can be on several devices" do
    devices(:two).dashboards = [ @kitchen ]

    assert_equal [ devices(:one), devices(:two) ].sort_by(&:id),
                 @kitchen.reload.devices.sort_by(&:id)
  end

  test "the same pairing cannot be recorded twice" do
    duplicate = DeviceDashboard.new(device: @device, dashboard: @kitchen)

    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save(validate: false) }
  end

  # --- which dashboard is actually on the panel ---

  test "the first assignment becomes the one showing" do
    device = Device.create!(name: "Fresh", bit_depth: 1, image_format: "bmp", rotation: 0)
    assert_nil device.dashboard

    device.dashboards = [ @office ]
    assert_equal @office, device.reload.dashboard
  end

  test "an explicit choice among the assigned ones is kept" do
    @device.dashboards = [ @kitchen, @office ]
    @device.update!(dashboard: @office)

    assert_equal @office, @device.reload.dashboard
  end

  test "choosing an unassigned dashboard falls back instead of sticking" do
    @device.dashboards = [ @kitchen ]
    @device.update!(dashboard: @office)

    assert_equal @kitchen, @device.reload.dashboard,
                 "a panel cannot show a dashboard it is not assigned"
  end

  test "unassigning the dashboard being shown falls back to another" do
    @device.dashboards = [ @kitchen, @office ]
    @device.update!(dashboard: @office)

    @device.device_dashboards.find_by!(dashboard: @office).destroy
    @device.save!

    assert_equal @kitchen, @device.reload.dashboard
  end

  test "unassigning the last dashboard leaves nothing showing" do
    @device.dashboards = []
    @device.save!

    assert_nil @device.reload.dashboard
    assert_empty @device.dashboards
  end

  test "other_dashboards lists what it could switch to" do
    @device.dashboards = [ @kitchen, @office ]
    @device.update!(dashboard: @kitchen)

    assert_equal [ @office ], @device.reload.other_dashboards.to_a
  end

  test "destroying a dashboard clears it off the panels showing it" do
    @device.dashboards = [ @kitchen ]
    assert_equal @kitchen, @device.reload.dashboard

    @kitchen.destroy!

    @device.reload
    assert_nil @device.dashboard
    assert_empty @device.dashboards
  end

  test "destroying a device takes its assignments with it" do
    @device.dashboards = [ @kitchen, @office ]

    assert_difference "DeviceDashboard.count", -2 do
      @device.destroy!
    end
  end

  test "sleep_seconds switches between day and night rates" do
    @device.update!(time_zone: "America/New_York", active_from_hour: 6,
                    active_until_hour: 23, refresh_seconds: 300,
                    night_refresh_seconds: 3600)
    zone = ActiveSupport::TimeZone["America/New_York"]

    assert_equal 300,  @device.sleep_seconds(zone.parse("2026-09-06 12:00"))
    assert_equal 3600, @device.sleep_seconds(zone.parse("2026-09-06 03:00"))
    assert_equal 3600, @device.sleep_seconds(zone.parse("2026-09-06 23:30"))
  end
end
