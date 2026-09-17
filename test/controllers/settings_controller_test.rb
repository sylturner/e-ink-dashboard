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

  test "the server address is labeled and explained" do
    get edit_settings_url

    assert_select "label[for=app_setting_server_url]", "Server address"
    assert_select "input[type=url][name=?][aria-describedby=app_setting_server_url_hint]", "app_setting[server_url]"
    assert_select ".form-text#app_setting_server_url_hint", /QR code/
  end

  test "a new server address asks claimed panels for a new frame" do
    Device.update_all(refresh_requested_at: nil)

    patch settings_url, params: { app_setting: { server_url: "http://192.168.1.10:3000/" } }

    assert_redirected_to edit_settings_url
    assert_equal "http://192.168.1.10:3000", @setting.reload.server_url
    assert Device.claimed.all? { it.refresh_requested_at.present? }
  end

  test "a server address with a path is refused" do
    patch settings_url, params: { app_setting: { server_url: "http://nas.local/notes" } }

    assert_response :unprocessable_content
    assert_select ".app-settings ul.errors li", "Server address must be a scheme, host and port, like http://192.168.1.10:3000"
    assert_select "input.is-invalid[name=?]", "app_setting[server_url]"
    assert_nil @setting.reload.server_url
  end

  test "new news tiles' headline template is edited here, without asking panels for a frame" do
    Device.update_all(refresh_requested_at: nil)
    get edit_settings_url

    assert_select "fieldset legend", "New news tiles"
    assert_select "select[name=?] option[selected][value=?]", "app_setting[news_template][lines][0][field]", "title"

    patch settings_url, params: { app_setting: { news_template: {
      "image" => { "placement" => "above", "size" => "medium" },
      "lines" => { "0" => { "field" => "summary", "size" => "small", "clamp" => "4" } }
    } } }

    assert_redirected_to edit_settings_url
    assert_equal [ "above", "{summary}" ], @setting.reload.news_template.then { [ it.image.placement, it.lines.first.tokens ] }
    assert_equal 0, Device.where.not(refresh_requested_at: nil).count
  end
end
