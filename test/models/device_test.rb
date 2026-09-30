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

  # --- stepping through its dashboards ---

  # Kitchen, Office, Hallway, in that order whatever their ids.
  def assign_three
    hallway = Dashboard.create!(name: "Hallway")
    @device.dashboards = []
    [ hallway, @office, @kitchen ].zip([ 2, 1, 0 ]).each do |dashboard, position|
      @device.device_dashboards.create!(dashboard:, position:)
    end
    @device.reload.update!(dashboard: @kitchen)
    hallway
  end

  test "stepping moves through the panel's own dashboards in order, wrapping at either end" do
    hallway = assign_three
    unassigned = Dashboard.create!(name: "Attic")

    @device.step_dashboard!(1)
    assert_equal @office, @device.reload.dashboard

    @device.step_dashboard!(2)
    assert_equal @kitchen, @device.reload.dashboard

    @device.step_dashboard!(-1)
    assert_equal hallway, @device.reload.dashboard

    assert_not_includes [ @device.reload.dashboard ], unassigned
  end

  test "a panel with nothing assigned has nowhere to step" do
    @device.dashboards = []
    @device.save!

    @device.step_dashboard!(1)
    assert_nil @device.reload.dashboard
  end

  test "the navigation strip is off until the panel asks for it" do
    assign_three

    assert_nil @device.navigation
  end

  test "navigation names the neighbors and the position of the dashboard drawn" do
    hallway = assign_three
    @device.update!(show_navigation: true)

    navigation = @device.navigation
    assert_equal [ hallway, @kitchen, @office ], [ navigation.previous_dashboard, navigation.current, navigation.next_dashboard ]
    assert_equal [ 1, 3 ], [ navigation.position, navigation.count ]

    at_end = @device.navigation(hallway)
    assert_equal [ @office, @kitchen, 3 ], [ at_end.previous_dashboard, at_end.next_dashboard, at_end.position ]
  end

  test "navigation draws a dashboard being edited as it is, and none it isn't assigned" do
    assign_three
    @device.update!(show_navigation: true)

    @office.name = "Study"
    assert_equal "Study", @device.navigation(@office).current.name
    assert_nil @device.navigation(Dashboard.create!(name: "Attic"))
  end

  test "changing a panel's dashboards asks for a new frame only when its strip names them" do
    @device.update_columns(refresh_requested_at: nil)
    @device.device_dashboards.create!(dashboard: @office)
    assert_nil @device.reload.refresh_requested_at

    @device.update!(show_navigation: true)
    @device.update_columns(refresh_requested_at: nil)
    @device.device_dashboards.find_by!(dashboard: @office).destroy
    assert_not_nil @device.reload.refresh_requested_at
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

  # --- the schedule ---

  # The Kitchen dashboard mornings, the Office one from 11:00 to 18:00, on
  # the panel's own clock (Los Angeles).
  def schedule_kitchen_and_office(default: nil)
    @device.dashboards = [ @kitchen, @office ]
    @device.update!(default_dashboard: default)
    kitchen, office = @device.device_dashboards.partition { it.dashboard == @kitchen }.map(&:first)

    kitchen.schedule_slots.create!(days: ScheduleSlot::DAYS.to_a, from_time: "06:00", until_time: "11:00")
    office.schedule_slots.create!(days: ScheduleSlot::DAYS.to_a, from_time: "11:00", until_time: "18:00")
    @device.reload
  end

  def pacific(hour, minute = 0, second = 0)
    ActiveSupport::TimeZone["America/Los_Angeles"].local(2026, 9, 28, hour, minute, second)
  end

  test "without a schedule nothing is switched" do
    assert @device.schedule.empty?
    assert_not @device.apply_schedule!(pacific(9))
    assert_equal @kitchen, @device.reload.dashboard
  end

  test "the schedule switches the panel once each stretch begins, and asks for a frame" do
    schedule_kitchen_and_office
    @device.update_columns(refresh_requested_at: nil)

    assert @device.apply_schedule!(pacific(11, 1))
    assert_equal @office, @device.reload.dashboard
    assert_not_nil @device.refresh_requested_at

    assert_not @device.apply_schedule!(pacific(12)), "it's the same stretch"
  end

  test "reading the schedule on the panel's clock, not the app's" do
    schedule_kitchen_and_office

    # 11:30 in New York is 8:30 in Los Angeles.
    @device.apply_schedule!(ActiveSupport::TimeZone["America/New_York"].local(2026, 9, 28, 11, 30))
    assert_equal @kitchen, @device.reload.dashboard
  end

  test "a switch by hand lasts until the next stretch begins" do
    schedule_kitchen_and_office
    @device.apply_schedule!(pacific(7))
    @device.update!(dashboard: @office)

    assert_not @device.apply_schedule!(pacific(9))
    assert_equal @office, @device.reload.dashboard

    @device.update!(dashboard: @kitchen)
    assert @device.apply_schedule!(pacific(11))
    assert_equal @office, @device.reload.dashboard
  end

  test "between times it shows the default, or keeps what it shows" do
    schedule_kitchen_and_office
    @device.apply_schedule!(pacific(12))

    assert_not @device.apply_schedule!(pacific(19))
    assert_equal @office, @device.reload.dashboard

    @device.update!(default_dashboard: @kitchen)
    @device.apply_schedule!(pacific(12, 30))
    assert @device.apply_schedule!(pacific(20))
    assert_equal @kitchen, @device.reload.dashboard
  end

  test "the default is dropped when it's unassigned" do
    schedule_kitchen_and_office(default: @office)
    assert_equal @office, @device.default_dashboard

    @device.device_dashboards.find_by(dashboard: @office).destroy
    assert_nil @device.reload.default_dashboard
    assert_equal 1, @device.schedule_slots.count
  end

  test "destroying a dashboard clears it as a panel's default" do
    schedule_kitchen_and_office(default: @office)
    @office.destroy

    assert_nil @device.reload.default_dashboard_id
  end

  test "the panel sleeps no later than just after the next switch" do
    schedule_kitchen_and_office

    # Daytime is 300s, so a switch 2 minutes off cuts it short...
    assert_equal 120 + Device::SCHEDULE_WAKE_MARGIN, @device.sleep_seconds(pacific(10, 58))
    # ...but never below the minimum, or when the rate comes first.
    assert_equal CheckInSchedule::MIN_SLEEP, @device.sleep_seconds(pacific(10, 59, 30))
    assert_equal 300, @device.sleep_seconds(pacific(9))

    # At night the hourly rate gives way to the morning's switch.
    assert_equal 30.minutes + Device::SCHEDULE_WAKE_MARGIN, @device.sleep_seconds(pacific(5, 30))
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

  test "a panel without a zone of its own follows the app's" do
    @device.update!(time_zone: nil, active_from_hour: 6, active_until_hour: 23,
                    refresh_seconds: 300, night_refresh_seconds: 3600)
    at = Time.utc(2026, 9, 6, 12) # 8:00 in New York, 5:00 in Los Angeles
    setting = app_settings(:one)

    setting.update!(time_zone: "America/New_York")
    setting.apply do
      assert_equal 8, @device.local_time(at).hour
      assert_equal 300, @device.sleep_seconds(at)
    end

    setting.update!(time_zone: "America/Los_Angeles")
    setting.apply { assert_equal 3600, @device.sleep_seconds(at) }
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

    @device.update!(show_navigation: true)
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

  # --- what the firmware can decode ---

  test "a BMP only works at the one size TRMNL's firmware decodes" do
    @device.width = 1024
    assert_not @device.valid?
    assert @device.errors.of_kind?(:image_format, :bmp_size)

    @device.image_format = "png"
    assert @device.valid?
  end

  test "a panel is sent a BMP at 800x480 and a PNG otherwise" do
    assert_equal "bmp", Device.image_format_for(800, 480)
    assert_equal "png", Device.image_format_for(960, 540)
    assert_equal "png", Device.image_format_for(nil, nil)
  end

  test "the charge is estimated from the battery voltage" do
    assert_equal 50, Device.battery_percent_for(3.75)
    assert_equal 100, Device.battery_percent_for(4.4)
    assert_equal 0, Device.battery_percent_for(3.0)
    assert_nil Device.battery_percent_for(nil)
    assert_nil Device.battery_percent_for(0.0)
  end
end
