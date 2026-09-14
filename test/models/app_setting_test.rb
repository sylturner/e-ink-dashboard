require "test_helper"

class AppSettingTest < ActiveSupport::TestCase
  setup do
    @setting = app_settings(:one)
  end

  test "current is the one row" do
    assert_equal @setting, AppSetting.current
  end

  test "current creates the row when there isn't one" do
    AppSetting.delete_all

    assert_difference("AppSetting.count", 1) { AppSetting.current }
    assert_equal "Etc/UTC", AppSetting.current.time_zone
  end

  test "a Rails zone name is stored as its IANA name" do
    @setting.update!(time_zone: "Eastern Time (US & Canada)")

    assert_equal "America/New_York", @setting.time_zone
  end

  test "the time zone must be present and known" do
    [ "", "Mars/Olympus_Mons" ].each do |zone|
      @setting.time_zone = zone
      assert_not @setting.valid?, "#{zone.inspect} should be rejected"
    end
  end

  test "units, clock and week start come from their lists" do
    @setting.assign_attributes(units: "kelvin", clock: "36h", week_start: "friday")

    assert_not @setting.valid?
    assert_equal %i[clock units week_start], @setting.errors.attribute_names.sort
  end

  test "the schedule is bounded as a panel's is" do
    @setting.assign_attributes(refresh_seconds: 30, night_refresh_seconds: 7.hours.to_i,
                               active_from_hour: 24, active_until_hour: 0)

    assert_not @setting.valid?
    assert_equal %i[active_from_hour active_until_hour night_refresh_seconds refresh_seconds],
                 @setting.errors.attribute_names.sort
  end

  test "panel_defaults is the schedule a new panel starts with" do
    assert_equal({ refresh_seconds: 900, night_refresh_seconds: 3600, active_from_hour: 6, active_until_hour: 23 },
                 @setting.panel_defaults)
  end

  test "apply sets the zone and week for the block, then restores them" do
    @setting.update!(time_zone: "America/Chicago", week_start: "monday")
    zone, week_start = Time.zone, Date.beginning_of_week

    @setting.apply do
      assert_equal "America/Chicago", Time.zone.name
      assert_equal Date.new(2026, 9, 7), Date.new(2026, 9, 13).beginning_of_week, "a Sunday ends a Monday week"
    end

    assert_equal zone, Time.zone
    assert_equal week_start, Date.beginning_of_week
  end

  test "only the settings a frame is drawn with call for new frames" do
    @setting.update!(units: "metric", refresh_seconds: 1200)
    assert_not @setting.frame_settings_changed?

    @setting.update!(clock: "24h")
    assert @setting.frame_settings_changed?

    @setting.update!(server_url: "http://nas.local")
    assert @setting.frame_settings_changed?, "a note tile's QR code links to the server address"
  end

  test "the server address is stored bare, and a cleared one as nil" do
    @setting.update!(server_url: " http://192.168.1.10:3000/ ")
    assert_equal "http://192.168.1.10:3000", @setting.server_url

    @setting.update!(server_url: "")
    assert_nil @setting.server_url
  end

  test "the server address is a scheme, a host and a port, and nothing more" do
    [ "192.168.1.10:3000", "nas.local", "ftp://nas.local", "http://", "http://nas.local/notes",
      "http://nas.local?x=1", "http://me@nas.local", "http://nas local" ].each do |url|
      @setting.server_url = url
      assert_not @setting.valid?, "#{url.inspect} should be rejected"
      assert_equal [ "must be a scheme, host and port, like http://192.168.1.10:3000" ], @setting.errors[:server_url]
    end

    [ "http://nas.local", "https://dashboard.example.com", "http://192.168.1.10:3000" ].each do |url|
      @setting.server_url = url
      assert @setting.valid?, "#{url.inspect} should be accepted"
    end
  end

  test "url_options point routes at the server address" do
    assert_nil @setting.url_options

    @setting.server_url = "https://dashboard.example.com"
    assert_equal({ protocol: "https", host: "dashboard.example.com", port: 443 }, @setting.url_options)
  end
end
