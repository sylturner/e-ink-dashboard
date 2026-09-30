require "test_helper"

class DashboardItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dashboard_item = dashboard_items(:one)
  end

  test "should get index" do
    get dashboard_items_url
    assert_response :success
  end

  test "should get new" do
    get new_dashboard_item_url
    assert_response :success
  end

  test "should create dashboard_item" do
    assert_difference("DashboardItem.count") do
      post dashboard_items_url, params: { dashboard_item: { col: @dashboard_item.col, col_span: @dashboard_item.col_span, dashboard_id: @dashboard_item.dashboard_id, kind: @dashboard_item.kind, position: @dashboard_item.position, row: @dashboard_item.row, row_span: @dashboard_item.row_span, settings: @dashboard_item.settings, title: @dashboard_item.title, view: @dashboard_item.view, visible: @dashboard_item.visible } }
    end

    assert_redirected_to edit_dashboard_url(@dashboard_item.dashboard)
  end

  test "should show dashboard_item" do
    get dashboard_item_url(@dashboard_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_dashboard_item_url(@dashboard_item)
    assert_response :success
  end

  test "the inspector's form tells the builder which tile its changes preview" do
    get edit_dashboard_item_url(@dashboard_item)

    assert_select "form[data-grid-target=draft][data-item-id=?]", @dashboard_item.id.to_s
    assert_select "select[name=?][data-item-form-target=kind]", "dashboard_item[kind]"
  end

  test "should update dashboard_item" do
    patch dashboard_item_url(@dashboard_item), params: { dashboard_item: { col: @dashboard_item.col, col_span: @dashboard_item.col_span, dashboard_id: @dashboard_item.dashboard_id, kind: @dashboard_item.kind, position: @dashboard_item.position, row: @dashboard_item.row, row_span: @dashboard_item.row_span, settings: @dashboard_item.settings, title: @dashboard_item.title, view: @dashboard_item.view, visible: @dashboard_item.visible } }
    assert_redirected_to edit_dashboard_url(@dashboard_item.dashboard)
  end

  test "should destroy dashboard_item" do
    assert_difference("DashboardItem.count", -1) do
      delete dashboard_item_url(@dashboard_item)
    end

    assert_redirected_to edit_dashboard_url(@dashboard_item.dashboard)
  end

  test "reposition moves and resizes the item" do
    patch reposition_dashboard_item_url(@dashboard_item),
          params: { dashboard_item: { col: 3, row: 2, col_span: 2, row_span: 2 } },
          as: :json

    assert_response :success
    assert JSON.parse(response.body)["ok"]

    @dashboard_item.reload
    assert_equal [ 3, 2, 2, 2 ],
                 [ @dashboard_item.col, @dashboard_item.row,
                   @dashboard_item.col_span, @dashboard_item.row_span ]
  end

  test "reposition refuses a placement that leaves the grid" do
    before = @dashboard_item.slice(:col, :row, :col_span, :row_span)

    patch reposition_dashboard_item_url(@dashboard_item),
          params: { dashboard_item: { col: 6, row: 1, col_span: 4, row_span: 3 } },
          as: :json

    assert_response :unprocessable_content

    body = JSON.parse(response.body)
    assert_not body["ok"]
    assert_includes body["errors"].join(" "), "extends past the grid"
    assert_equal before, @dashboard_item.reload.slice(:col, :row, :col_span, :row_span)
  end

  test "create places the item in the first free slot" do
    dashboard = dashboards(:one)

    post dashboard_items_url,
         params: { dashboard_item: { dashboard_id: dashboard.id, kind: "clock",
                                     col_span: 2, row_span: 2, visible: true } }

    assert_redirected_to edit_dashboard_url(dashboard)

    item = DashboardItem.order(:id).last
    # Fixture :one holds cols 1-4 / rows 1-3, so the first 2x2 opening is
    # at column 5 on row 1.
    assert_equal [ 5, 1 ], [ item.col, item.row ]
  end

  test "create reports when nothing fits" do
    dashboard = dashboards(:one)

    assert_no_difference("DashboardItem.count") do
      post dashboard_items_url,
           params: { dashboard_item: { dashboard_id: dashboard.id, kind: "clock",
                                       col_span: 8, row_span: 8, visible: true } }
    end

    assert_redirected_to edit_dashboard_url(dashboard)
    assert_match(/No room/, flash[:alert])
  end

  test "edit renders the layouts and settings for the item's kind" do
    get edit_dashboard_item_url(@dashboard_item) # weather

    assert_response :success
    assert_select "select[name=?] option", "dashboard_item[view]", 3
    assert_select "option[value=?]", "forecast"
    assert_select "option[value=?]", "month", 0, "calendar layouts must not leak in"
    assert_select "input[name=?]", "dashboard_item[settings][day_count]"
  end

  test "edit previews another kind without saving it" do
    get edit_dashboard_item_url(@dashboard_item, kind: "calendar")

    assert_response :success
    assert_select "option[value=?]", "month"
    assert_select "input[name=?]", "dashboard_item[settings][parts][today][times]"
    assert_equal "weather", @dashboard_item.reload.kind, "the preview must not persist"
  end

  test "edit ignores an unknown kind" do
    get edit_dashboard_item_url(@dashboard_item, kind: "Kernel")

    assert_response :success
    assert_select "option[value=?][selected]", "current"
  end

  test "the source select offers only the kind's provider type" do
    get edit_dashboard_item_url(@dashboard_item, kind: "news")

    assert_response :success
    assert_select "select[name=?] option", "dashboard_item[source_ids][]" do |options|
      names = options.map(&:text).reject(&:blank?)
      assert_includes names, sources(:three).name  # RSS
      assert_not_includes names, sources(:one).name # weather
      assert_not_includes names, sources(:two).name # iCal
    end
  end

  test "settings fields are styled by the form builder" do
    get edit_dashboard_item_url(@dashboard_item) # weather: day_count is a number

    assert_select "label[for=?]", "dashboard_item_settings_day_count"
    assert_select "input.form-control[type=number][id=?][name=?]",
                  "dashboard_item_settings_day_count", "dashboard_item[settings][day_count]"
  end

  test "each layout gets a Show group of its parts, and only the current one is visible" do
    get edit_dashboard_item_url(@dashboard_item) # weather / current

    assert_select "fieldset[data-views=?]:not([hidden])", "current" do
      assert_select "legend", "Show"

      # The hidden "0" partner is what turns a part off.
      assert_select "input[type=hidden][name=?][value='0']", "dashboard_item[settings][parts][current][icon]"
      assert_select "input.form-check-input[type=checkbox][name=?][checked]", "dashboard_item[settings][parts][current][icon]"
      assert_select "label.form-check-label[for=?]", "dashboard_item_settings_parts_current_icon", "Icon"

      assert_select "input[type=checkbox][name=?]", "dashboard_item[settings][parts][current][humidity]" do |boxes|
        assert_nil boxes.first["checked"], "humidity starts hidden"
      end

      assert_select "label[for=?]", "dashboard_item_settings_sizes_current_icon", text: /\AIcon\s*Size\z/
      assert_select "select.form-select[name=?] option[selected]", "dashboard_item[settings][sizes][current][icon]", "Medium"
      assert_select "select[name=?]", "dashboard_item[settings][sizes][current][condition]", 0
    end

    assert_select "fieldset[data-views=?][hidden]", "forecast"
    assert_select "fieldset[data-views=?][hidden]", "hourly"
  end

  test "a kind without parts renders no Show group" do
    get edit_dashboard_item_url(@dashboard_item, kind: "text")

    assert_response :success
    assert_select "legend", text: "Show", count: 0
  end

  test "every kind gets a Look group, folded until the tile has a look" do
    get edit_dashboard_item_url(@dashboard_item, kind: "clock")

    assert_response :success
    assert_select "details:not([open]) summary", "Look"
    assert_select "select[name=?] option[value='']", "dashboard_item[settings][look][border]", "From the theme"
    assert_select ".font-picker select[name=?] option[value=jersey][data-font-class=font-preview--jersey]",
                  "dashboard_item[settings][look][font]"
    assert_select ".font-picker select[name=?]", "dashboard_item[settings][look][header_font]"
    assert_select "input[type=hidden][name=?][value='0']", "dashboard_item[settings][look][invert]"

    @dashboard_item.update!(settings: { "look" => { "border" => "thick" } })
    get edit_dashboard_item_url(@dashboard_item)

    assert_select "details[open]"
    assert_select "select[name=?] option[selected][value=thick]", "dashboard_item[settings][look][border]"
  end

  test "a text tile is formatted by default, in the Markdown editor with the tokens listed" do
    get edit_dashboard_item_url(@dashboard_item, kind: "text")

    assert_response :success
    assert_select "select[name=?] option[selected][value=formatted]", "dashboard_item[view]"
    assert_select "[data-controller=markdown-editor][data-markdown-editor-upload-url-value=?]",
                  "/rails/active_storage/direct_uploads"
    assert_select "[role=toolbar][aria-controls=dashboard_item_settings_body] button[aria-label=Bold][aria-keyshortcuts]"
    assert_select "textarea#dashboard_item_settings_body[name=?][aria-describedby=?]", "dashboard_item[settings][body]",
                  "dashboard_item_settings_body_editor_hint dashboard_item_settings_body_tokens"
    assert_select "textarea[data-action*='keydown.meta+b->markdown-editor#bold:prevent']"
    assert_select "label[for=dashboard_item_settings_body]", "Text"
    assert_select "#dashboard_item_settings_body_tokens", /\{\{CURRENT_TIME\}\}/
    assert_select ".token-list dt code", "{{DAYS_UNTIL:2026-12-25}}"
    assert_select "[role=toolbar] .font-picker[data-font-picker-menu-value=true] select[aria-label=Font][data-action~='markdown-editor#font']" do
      assert_select "option:first-child[value='']", "Font"
    end
    assert_select "[role=toolbar] select[aria-label=Size][data-action~='markdown-editor#size'] option[value=huge]", "Huge"
  end

  test "a custom newspaper's font settings are font pickers" do
    get edit_dashboard_item_url(@dashboard_item, kind: "newspaper")

    assert_select ".font-picker select[name=?] option[value=ransom]", "dashboard_item[settings][masthead_font]"
    assert_select ".font-picker select[name=?] option[selected][value=jersey]", "dashboard_item[settings][headline_font]"
    assert_select ".font-picker select[name=?]", "dashboard_item[settings][layout]", 0
  end

  test "a kind with no sources renders no source select" do
    get edit_dashboard_item_url(@dashboard_item, kind: "clock")

    assert_response :success
    assert_select "select[name=?]", "dashboard_item[source_ids][]", 0
    assert_select "input[type=hidden][name=?][value='']", "dashboard_item[source_ids][]"
  end

  test "switching a tile to a kind with no sources lets go of its sources" do
    assert @dashboard_item.sources.any?

    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "clock", view: "time", source_ids: [ "" ] }
    }

    assert_redirected_to edit_dashboard_url(@dashboard_item.dashboard)
    assert_equal "clock", @dashboard_item.reload.kind
    assert_empty @dashboard_item.sources
  end

  test "settings round-trip through the form" do
    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "forecast", title: "Week",
                        settings: { "day_count" => "7", "hour_count" => "6" } }
    }

    assert_redirected_to edit_dashboard_url(@dashboard_item.dashboard)
    @dashboard_item.reload
    assert_equal "forecast", @dashboard_item.view
    assert_equal 7, @dashboard_item.setting("day_count")
  end

  test "parts and sizes round-trip through the form, per layout" do
    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: {
        kind: "weather", view: "current",
        settings: {
          "parts" => { "current" => { "icon" => "0", "humidity" => "1" },
                       "forecast" => { "precip" => "1" } },
          "sizes" => { "current" => { "temperature" => "large" } }
        }
      }
    }

    assert_redirected_to edit_dashboard_url(@dashboard_item.dashboard)
    @dashboard_item.reload
    assert_not @dashboard_item.shows?("icon")
    assert @dashboard_item.shows?("humidity")
    assert @dashboard_item.shows?("precip", view: "forecast")
    assert_equal "t-xl", @dashboard_item.size_of("temperature")
  end

  test "a part can be switched off through the form" do
    item = dashboard_items(:two) # calendar / week, times default to shown
    assert item.shows?("times")

    patch dashboard_item_url(item), params: {
      dashboard_item: { kind: "calendar", view: "week",
                        settings: { "parts" => { "week" => { "times" => "0" } } } }
    }

    assert_redirected_to edit_dashboard_url(item.dashboard)
    assert_not item.reload.shows?("times")
  end

  test "an incompatible layout is rejected with an error" do
    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "month" }
    }

    assert_response :unprocessable_content
    assert_select "ul.errors li", /isn't available for Weather/
    assert_equal "current", @dashboard_item.reload.view
  end

  test "attaching two sources to a single-source kind is rejected" do
    second = Source.create!(
      name: "Other weather", refresh_seconds: 900,
      providable: WeatherProvider.new(latitude: 1, longitude: 2, units: "metric")
    )

    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "current",
                        source_ids: [ sources(:one).id, second.id ] }
    }

    assert_response :unprocessable_content
    assert_select "ul.errors li", /only one is allowed for Weather/
  end

  test "saving a tile asks its dashboard's panels for a new frame" do
    at = Time.utc(2026, 9, 13, 12)

    travel_to(at) do
      patch dashboard_item_url(@dashboard_item), params: { dashboard_item: { title: "Outside" } }
    end

    assert_equal at, devices(:one).reload.refresh_requested_at # shows dashboard one
    assert_not_equal at, devices(:two).reload.refresh_requested_at, "another dashboard's panel is left alone"
  end

  test "moving, adding and deleting a tile ask for a new frame too" do
    requests = [
      -> { patch reposition_dashboard_item_url(@dashboard_item), params: { dashboard_item: { col: 3, row: 2, col_span: 2, row_span: 2 } }, as: :json },
      -> { post dashboard_items_url, params: { dashboard_item: { dashboard_id: @dashboard_item.dashboard_id, kind: "clock", col_span: 2, row_span: 2 } } },
      -> { delete dashboard_item_url(@dashboard_item) }
    ]

    requests.each.with_index(1) do |request, hour|
      at = Time.utc(2026, 9, 13, hour)
      travel_to(at) { request.call }

      assert_equal at, devices(:one).reload.refresh_requested_at
    end
  end

  test "a rejected change asks for nothing" do
    assert_no_changes -> { devices(:one).reload.refresh_requested_at } do
      patch dashboard_item_url(@dashboard_item), params: {
        dashboard_item: { kind: "weather", view: "month" }
      }
    end
  end

  test "a note's QR code part says what it needs until the server address is set" do
    box  = "dashboard_item[settings][parts][formatted][qr_code]"
    hint = "dashboard_item_settings_parts_formatted_qr_code_hint"

    get edit_dashboard_item_url(@dashboard_item, kind: "note")

    assert_select "input[type=checkbox][name=?][aria-describedby=?]", box, hint
    assert_select ".form-text##{hint} a[href=?][data-turbo-frame=_top]", edit_settings_path, "Settings"

    AppSetting.current.update!(server_url: "http://nas.local")
    get edit_dashboard_item_url(@dashboard_item, kind: "note")

    assert_select "input[type=checkbox][name=?]:not([aria-describedby])", box
    assert_select "##{hint}", 0
  end

  test "a checklist's inspector offers what to do with done items, and its parts" do
    get edit_dashboard_item_url(@dashboard_item, kind: "checklist", view: "columns")

    assert_response :success
    assert_select "select[name=?] option", "dashboard_item[settings][done_items]", 3
    assert_select "input[name=?]", "dashboard_item[settings][column_count]"
    %w[checkboxes progress qr_code].each do |part|
      assert_select "input[type=checkbox][name=?]", "dashboard_item[settings][parts][columns][#{part}]"
    end
    assert_select ".form-text#dashboard_item_settings_parts_columns_qr_code_hint a[href=?]", edit_settings_path
  end

  test "a news tile's inspector edits its headline template, and lists its feeds' fields" do
    sources(:three).update!(payload: { "items" => [ { "title" => "A", "fields" => { "title" => "A", "dc:creator" => "Ada" } } ] })
    get edit_dashboard_item_url(@dashboard_item, kind: "news")

    assert_response :success
    assert_select "fieldset[data-views=?]", "headlines" do
      assert_select "legend", "Each headline"
      assert_select "select[name=?] option[selected][value=?]", "dashboard_item[settings][template][image][placement]", "none"
      assert_select "select[name=?] option[selected][value=?]", "dashboard_item[settings][template][lines][0][field]", "title"
      assert_select "label[for=?]", "dashboard_item_settings_template_lines_2_format", "Format"
      assert_select "[data-news-template-target=format][hidden] input[name=?]", "dashboard_item[settings][template][lines][0][format]"
      assert_select "[data-news-template-target=style][hidden] select[name=?]", "dashboard_item[settings][template][lines][1][size]"
    end
    # The kind was only switched in the form, so the tile has none of the feed's sources yet.
    assert_select "details ul code", 0

    news = dashboards(:one).dashboard_items.create!(kind: "news", col: 1, row: 7, col_span: 2, row_span: 2,
                                                    sources: [ sources(:three) ])
    get edit_dashboard_item_url(news)

    assert_select "details ul code", "{dc:creator}"
    assert_select "details ul code", 1
  end

  test "a news tile's template round-trips through the form" do
    news = dashboards(:one).dashboard_items.create!(kind: "news", col: 1, row: 7, col_span: 2, row_span: 2)

    patch dashboard_item_url(news), params: { dashboard_item: { kind: "news", view: "headlines", settings: {
      "event_limit" => "4",
      "template" => { "image" => { "placement" => "left", "size" => "large" },
                      "lines" => { "0" => { "field" => "title", "size" => "large", "clamp" => "1" },
                                   "1" => { "field" => "custom", "format" => "{source} · {age}", "size" => "small", "clamp" => "1" },
                                   "2" => { "field" => "none", "size" => "small", "clamp" => "1" } } }
    } } }

    template = news.reload.news_template
    assert_equal [ "left", "large" ], [ template.image.placement, template.image.size ]
    assert_equal [ "{title}", "{source} · {age}" ], template.lines.select(&:shown?).map(&:tokens)
  end

  test "a countdown's date and time are date and time fields, with hints" do
    get edit_dashboard_item_url(@dashboard_item, kind: "countdown")

    assert_select "input[type=date][name=?]", "dashboard_item[settings][date]"
    assert_select "input[type=time][name=?][aria-describedby=?]", "dashboard_item[settings][time]",
                  "dashboard_item_settings_time_hint"
    assert_select ".form-text#dashboard_item_settings_time_hint", /counting in hours/
    assert_select "select[name=?] option", "dashboard_item[settings][unit]", 2
  end

  test "a new rotation starts today" do
    travel_to Time.zone.parse("2026-09-06 12:00") do
      get edit_dashboard_item_url(@dashboard_item, kind: "rotation")
    end

    assert_select "textarea[name=?][aria-describedby=?]", "dashboard_item[settings][entries]",
                  "dashboard_item_settings_entries_hint"
    assert_select "input[type=date][name=?][value=?]", "dashboard_item[settings][start]", "2026-09-06"
  end

  test "a Wi-Fi QR code's password is filled in, not remembered, and says where it's kept" do
    @dashboard_item.update!(kind: "qr_code", view: "wifi", sources: [], settings: { "ssid" => "Home", "password" => "hunter22" })

    get edit_dashboard_item_url(@dashboard_item)

    assert_select "input[type=password][name=?][value=hunter22][autocomplete=off][aria-describedby=?]",
                  "dashboard_item[settings][password]", "dashboard_item_settings_password_hint"
    assert_select "#dashboard_item_settings_password_hint", /anyone who can open this app/
    assert_select "[data-views=link] textarea[name=?]", "dashboard_item[settings][text]"
  end

  test "a photo tile uploads its photo from the inspector, with no source" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photo.jpg").open, filename: "photo.jpg")
    @dashboard_item.update!(kind: "photo", view: "fill", sources: [], settings: { "image" => blob.signed_id })

    get edit_dashboard_item_url(@dashboard_item)

    assert_select "select[name^=?]", "dashboard_item[source_ids]", 0
    assert_select "[data-controller=image-field][data-image-field-upload-url-value=?]", "/rails/active_storage/direct_uploads" do
      assert_select "input[type=hidden][name=?][value=?][data-image-field-target=value]",
                    "dashboard_item[settings][image]", blob.signed_id
      assert_select "label[for=dashboard_item_settings_image]", "Photo"
      assert_select "input[type=file]#dashboard_item_settings_image:not([name])[accept='image/*'][aria-describedby=?]",
                    "dashboard_item_settings_image_hint"
      assert_select "figure:not([hidden]) img[src*=?][alt=?]", "/rails/active_storage/representations/", "The tile's photo"
      assert_select "button[data-action='image-field#remove']:not([hidden])", "Remove photo"
      assert_select "[role=status][data-image-field-target=status]"
    end
  end

  test "a photo tile without a photo offers only the upload" do
    get edit_dashboard_item_url(@dashboard_item, kind: "photo")

    assert_select "input[type=hidden][name=?]:not([value])", "dashboard_item[settings][image]"
    assert_select "figure[hidden][data-image-field-target=preview]"
    assert_select "button[hidden][data-image-field-target=remove]"
  end

  test "a tile with one source sends it as a list, so saving keeps it" do
    get edit_dashboard_item_url(@dashboard_item) # weather
    assert_select "select[name=?]:not([multiple])", "dashboard_item[source_ids][]"

    patch dashboard_item_url(@dashboard_item), params: {
      dashboard_item: { kind: "weather", view: "current", source_ids: [ sources(:one).id.to_s ] }
    }

    assert_equal [ sources(:one) ], @dashboard_item.reload.sources
  end

  test "a data tile's inspector takes its template, and lists its filters and its source's values" do
    source = Source.create!(name: "Outside", refresh_seconds: 900, providable: JsonProvider.new(url: "https://x.example"),
                            payload: { "data" => { "state" => "12" } })
    @dashboard_item.update!(kind: "data", view: "lines", sources: [ source ], settings: { "lines" => "{state}°" })

    get edit_dashboard_item_url(@dashboard_item)

    assert_select "select[name=?] option[selected]", "dashboard_item[source_ids][]", "Outside"
    assert_select "textarea[name=?][aria-describedby=?]", "dashboard_item[settings][lines]",
                  "dashboard_item_settings_lines_hint", "{state}°"
    assert_select "[data-views=big_stat] input[name=?]", "dashboard_item[settings][value]"
    assert_select "details summary", "Formatting a value"
    assert_select "details dt code", "{path|round} or {path|round:1}"
    assert_select "details table td code", "{state}"
  end

  test "a data tile without a source says where its values will come from" do
    get edit_dashboard_item_url(@dashboard_item, kind: "data")

    assert_select "details p", /Choose a source and save the tile/
  end
end
