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

  test "the next check-in is the sleep after the last one, and missing two is overdue" do
    @device.update!(time_zone: "UTC", active_from_hour: 0, active_until_hour: 24, refresh_seconds: 300)
    seen = Time.zone.parse("2026-09-06 12:00")
    @device.update_columns(last_seen_at: seen)

    assert_equal seen + 300, @device.next_check_in_at
    assert_not @device.overdue?(seen + 599)
    assert @device.overdue?(seen + 601)
  end

  test "a panel that has never checked in isn't overdue or due" do
    device = Device.new(name: "Fresh")

    assert_nil device.next_check_in_at
    assert_not device.overdue?
  end

  test "the time zone must be one the schedule can read" do
    @device.time_zone = "Mars/Olympus_Mons"
    assert_not @device.valid?
    assert_includes @device.errors[:time_zone], "isn't a time zone name"

    [ "America/Chicago", "Pacific Time (US & Canada)", "" ].each do |zone|
      @device.time_zone = zone
      assert @device.valid?, "#{zone.inspect} should be accepted"
    end
  end

  test "daytime hours must be clock hours, ending as late as midnight" do
    @device.assign_attributes(active_from_hour: 24, active_until_hour: 0)
    assert_not @device.valid?
    assert @device.errors.key?(:active_from_hour)
    assert @device.errors.key?(:active_until_hour)

    @device.assign_attributes(active_from_hour: 0, active_until_hour: 24)
    assert @device.valid?
  end

  test "only settings the frame is rendered from count as frame changes" do
    @device.update!(refresh_seconds: 900, rotation: 90, name: "Kitchen wall")
    assert_not @device.frame_settings_changed?

    @device.update!(dither: "none")
    assert @device.frame_settings_changed?
  end

  # --- enrollment and claiming ---

  test "every device gets a claim code, however the row was created" do
    device = Device.create!(name: "Hand made")

    assert_match(/\A[A-Z2-9]{4}\z/, device.claim_code)
  end

  test "claim codes avoid glyphs that misread on a low-res panel" do
    50.times do
      code = Device.generate_claim_code
      assert_no_match(/[ILO01]/, code, "#{code} contains an ambiguous glyph")
    end
  end

  test "claim codes are unique" do
    codes = Array.new(30) { Device.create!(name: "P").claim_code }

    assert_equal codes.size, codes.uniq.size
  end

  test "a device is claimed once it has something to show" do
    device = Device.create!(name: "Fresh")
    assert_not device.claimed?

    device.dashboards = [ @kitchen ]
    assert device.reload.claimed?
  end

  test "an unclaimed panel comes back quickly so claiming feels immediate" do
    device = Device.create!(name: "Fresh", refresh_seconds: 900,
                            night_refresh_seconds: 3600)

    assert_equal Device::UNCLAIMED_SLEEP, device.sleep_seconds
    assert_operator device.sleep_seconds, :<, 900

    device.dashboards = [ @kitchen ]
    assert_equal 900, device.reload.sleep_seconds(Time.current.change(hour: 12))
  end

  test "enroll! is keyed on a normalized MAC" do
    a = Device.enroll!(mac: "A4:CF:12:9B:0D:7E")
    b = Device.enroll!(mac: "  a4:cf:12:9b:0d:7e ")

    assert_equal a.id, b.id
    assert_equal "a4:cf:12:9b:0d:7e", a.mac_address
  end

  test "re-enrolling does not mint a new token or claim code" do
    device = Device.enroll!(mac: "aa:bb:cc:dd:ee:ff")
    token, code = device.token, device.claim_code

    again = Device.enroll!(mac: "aa:bb:cc:dd:ee:ff", attributes: { bit_depth: 2 })

    assert_equal token, again.token
    assert_equal code, again.claim_code
    assert_equal 2, again.bit_depth
  end

  # Zones and hours weren't validated before, so a saved one can be bad.
  test "re-enrolling repairs a schedule the panel could not save with" do
    device = Device.enroll!(mac: "aa:bb:cc:dd:ee:ff")
    device.update_columns(time_zone: "Mars/Olympus_Mons", active_from_hour: 30, active_until_hour: 0)

    again = Device.enroll!(mac: "aa:bb:cc:dd:ee:ff")

    assert_nil again.time_zone
    assert_equal [ 6, 23 ], [ again.active_from_hour, again.active_until_hour ]
  end

  test "re-enrolling does not reset the name someone chose" do
    device = Device.enroll!(mac: "aa:bb:cc:dd:ee:ff")
    device.update!(name: "Kitchen wall")

    assert_equal "Kitchen wall", Device.enroll!(mac: "aa:bb:cc:dd:ee:ff").name
  end
end
