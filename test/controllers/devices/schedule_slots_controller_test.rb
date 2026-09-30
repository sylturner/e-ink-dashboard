require "test_helper"

class Devices::ScheduleSlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one) # Kitchen panel, in Los Angeles
    @kitchen = device_dashboards(:one)
    @office = @device.device_dashboards.create!(dashboard: dashboards(:two), position: 1)
  end

  def slot_params(**overrides)
    { schedule_slot: { device_dashboard_id: @office.id, days: [ "", "1" ], from_time: "12:00", until_time: "17:00", **overrides } }
  end

  test "new offers the panel's dashboards, every day and the two times" do
    get new_device_schedule_slot_url(@device)

    assert_response :success
    assert_select "h1", "New time"
    assert_select ".breadcrumb a[href=?]", edit_device_path(@device), @device.name
    assert_select "form[action=?]", device_schedule_slots_path(@device) do
      assert_select "select[name=?] option", "schedule_slot[device_dashboard_id]", 2
      assert_select "fieldset legend", "Days"
      assert_select "input[type=checkbox][name=?][checked]", "schedule_slot[days][]", 7
      assert_select "input[type=time][name=?][required]", "schedule_slot[from_time]"
      assert_select "input[type=time][name=?][required]", "schedule_slot[until_time]"
      assert_select "#schedule_slot_from_time_hint", /America\/Los_Angeles/
    end
  end

  test "the day checkboxes start on the app's first day of the week and name each day" do
    AppSetting.current.update!(week_start: "monday")

    get new_device_schedule_slot_url(@device)

    assert_select "input[type=checkbox][name=?]", "schedule_slot[days][]" do |boxes|
      assert_equal %w[1 2 3 4 5 6 0], boxes.map { it["value"] }
      assert_equal "Monday", boxes.first["aria-label"]
    end
    assert_select "label[for=?]", "schedule_slot_days_1", "Mon"
  end

  test "adding a time returns to the device's page" do
    assert_difference -> { @office.schedule_slots.count } do
      post device_schedule_slots_url(@device), params: slot_params
    end

    slot = ScheduleSlot.last
    assert_equal [ [ 1 ], 720, 1020 ], [ slot.days, slot.from_minute, slot.until_minute ]
    assert_redirected_to edit_device_path(@device)
    follow_redirect!
    assert_select ".schedule-slots li", /Office.*Mondays, 12:00 PM to 5:00 PM/m
  end

  test "a time without days or times comes back with its errors" do
    assert_no_difference -> { ScheduleSlot.count } do
      post device_schedule_slots_url(@device), params: slot_params(days: [ "" ], from_time: "")
    end

    assert_response :unprocessable_content
    assert_select "ul.errors li", "Days can't be blank"
    assert_select "ul.errors li", "From can't be blank"
    assert_select "input.is-invalid[name=?]", "schedule_slot[from_time]"
    assert_select "input.is-invalid[type=checkbox]", 7
    assert_select ".invalid-feedback.d-block", "Days can't be blank"
  end

  test "a time can only be on the panel's own dashboards" do
    elsewhere = device_dashboards(:two)

    assert_no_difference -> { ScheduleSlot.count } do
      post device_schedule_slots_url(@device), params: slot_params(device_dashboard_id: elsewhere.id)
    end
    assert_response :unprocessable_content
  end

  test "editing a time changes it" do
    slot = @office.schedule_slots.create!(days: [ 1 ], from_time: "12:00", until_time: "17:00")

    get edit_device_schedule_slot_url(@device, slot)
    assert_select "input[name=?][value=?]", "schedule_slot[from_time]", "12:00"
    assert_select "input[type=checkbox][value=?][checked]", "1"
    assert_select "input[type=checkbox][checked]", 1

    patch device_schedule_slot_url(@device, slot), params: slot_params(device_dashboard_id: @kitchen.id, days: [ "", "1", "4" ], until_time: "18:30")

    assert_redirected_to edit_device_path(@device)
    slot.reload
    assert_equal [ @kitchen, [ 1, 4 ], 1110 ], [ slot.device_dashboard, slot.days, slot.until_minute ]
  end

  test "removing a time returns to the device's page" do
    slot = @office.schedule_slots.create!(days: [ 1 ], from_time: "12:00", until_time: "17:00")

    assert_difference -> { ScheduleSlot.count }, -1 do
      delete device_schedule_slot_url(@device, slot)
    end
    assert_redirected_to edit_device_path(@device)
  end

  test "another panel's times aren't reachable from this one" do
    slot = device_dashboards(:two).schedule_slots.create!(days: [ 1 ], from_time: "12:00", until_time: "17:00")

    get edit_device_schedule_slot_url(@device, slot)
    assert_response :not_found
  end
end
