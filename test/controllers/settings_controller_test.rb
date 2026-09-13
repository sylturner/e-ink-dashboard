require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @setting = app_settings(:one)
  end

  test "edit shows the settings form" do
    get edit_settings_url

    assert_response :success
    assert_select "h1", "Settings"
    assert_select ".app-settings form[action=?]", settings_path do
      assert_select "select[name=?] option[value=?]", "app_setting[time_zone]", "America/New_York", text: /Eastern Time/
      assert_select "select[name=?] option[selected][value=?]", "app_setting[time_zone]", "Etc/UTC"
      assert_select "select[name=?] option", "app_setting[clock]", text: "24-hour (13:30)"
      assert_select "select[name=?] option", "app_setting[week_start]", 2
      assert_select "select[name=?] option", "app_setting[units]", 2
      assert_select "input[name=?][value='900']", "app_setting[refresh_seconds]"
      assert_select "select[name=?] option", "app_setting[active_until_hour]", 24
    end
  end

  test "/settings lands on the edit page" do
    get "/settings"

    assert_redirected_to "/settings/edit"
  end

  test "update saves and says so" do
    patch settings_url, params: { app_setting: {
      time_zone: "America/Chicago", clock: "24h", week_start: "monday", units: "metric", refresh_seconds: 1200
    } }

    assert_redirected_to edit_settings_url
    @setting.reload
    assert_equal [ "America/Chicago", "24h", "monday", "metric", 1200 ],
                 [ @setting.time_zone, @setting.clock, @setting.week_start, @setting.units, @setting.refresh_seconds ]

    follow_redirect!
    assert_select ".alert[role=status]", /Settings were saved/
  end

  test "an unknown zone is rejected" do
    patch settings_url, params: { app_setting: { time_zone: "Nowhere/Special" } }

    assert_response :unprocessable_content
    assert_select ".app-settings ul.errors li", "Time zone isn't a time zone name"
    assert_equal "Etc/UTC", @setting.reload.time_zone
  end

  test "a change to how panels draw time asks claimed panels for a new frame" do
    waiting = Device.create!(name: "Waiting")
    Device.update_all(refresh_requested_at: nil)

    freeze_time do
      patch settings_url, params: { app_setting: { clock: "24h" } }

      assert Device.claimed.any?
      assert Device.claimed.all? { it.refresh_requested_at == Time.current }
    end
    assert_nil waiting.reload.refresh_requested_at
  end

  test "a change to what new sources start with doesn't" do
    Device.update_all(refresh_requested_at: nil)

    patch settings_url, params: { app_setting: { units: "metric" } }

    assert_equal 0, Device.where.not(refresh_requested_at: nil).count
  end
end
