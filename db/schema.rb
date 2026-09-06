# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_06_000418) do
  create_table "dashboard_item_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dashboard_item_id", null: false
    t.integer "position", default: 0
    t.integer "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["dashboard_item_id", "source_id"], name: "index_dis_on_item_and_source", unique: true
    t.index ["dashboard_item_id"], name: "index_dashboard_item_sources_on_dashboard_item_id"
    t.index ["source_id"], name: "index_dashboard_item_sources_on_source_id"
  end

  create_table "dashboard_items", force: :cascade do |t|
    t.integer "col", default: 1
    t.integer "col_span", default: 2
    t.datetime "created_at", null: false
    t.integer "dashboard_id", null: false
    t.string "kind"
    t.integer "position", default: 0
    t.integer "row", default: 1
    t.integer "row_span", default: 2
    t.json "settings", default: {}
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "view"
    t.boolean "visible", default: true
    t.index ["dashboard_id", "position"], name: "index_dashboard_items_on_dashboard_id_and_position"
    t.index ["dashboard_id"], name: "index_dashboard_items_on_dashboard_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "grid_columns", default: 8
    t.integer "grid_rows", default: 8
    t.string "name"
    t.string "theme", default: "default"
    t.datetime "updated_at", null: false
  end

  create_table "devices", force: :cascade do |t|
    t.integer "active_from_hour", default: 6
    t.integer "active_until_hour", default: 23
    t.integer "battery_percent"
    t.decimal "battery_voltage", precision: 4, scale: 2
    t.integer "bit_depth", default: 1
    t.datetime "created_at", null: false
    t.integer "dashboard_id"
    t.string "firmware_version"
    t.integer "height", default: 480
    t.string "image_format", default: "bmp"
    t.datetime "last_seen_at"
    t.string "name"
    t.integer "night_refresh_seconds", default: 3600
    t.datetime "refresh_requested_at"
    t.integer "refresh_seconds", default: 300
    t.integer "rotation", default: 0
    t.string "time_zone"
    t.string "token"
    t.datetime "updated_at", null: false
    t.integer "width", default: 800
    t.integer "wifi_rssi"
    t.index ["dashboard_id"], name: "index_devices_on_dashboard_id"
    t.index ["token"], name: "index_devices_on_token", unique: true
  end

  create_table "frames", force: :cascade do |t|
    t.integer "byte_size"
    t.string "checksum"
    t.datetime "created_at", null: false
    t.binary "data"
    t.integer "device_id", null: false
    t.string "format", default: "bmp"
    t.datetime "rendered_at"
    t.datetime "updated_at", null: false
    t.index ["device_id", "rendered_at"], name: "index_frames_on_device_id_and_rendered_at"
    t.index ["device_id"], name: "index_frames_on_device_id"
  end

  create_table "ical_providers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ical_url"
    t.boolean "include_all_day", default: true
    t.datetime "updated_at", null: false
  end

  create_table "rss_providers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feed_url"
    t.integer "max_items", default: 10
    t.datetime "updated_at", null: false
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "attempted_at"
    t.datetime "created_at", null: false
    t.integer "failure_count", default: 0
    t.datetime "fetched_at"
    t.string "last_error"
    t.string "name"
    t.json "payload", default: {}
    t.integer "providable_id", null: false
    t.string "providable_type", null: false
    t.integer "refresh_seconds", default: 900
    t.datetime "updated_at", null: false
    t.index ["providable_type", "providable_id"], name: "index_sources_on_providable"
  end

  create_table "weather_providers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "time_zone"
    t.string "units", default: "imperial"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "dashboard_item_sources", "dashboard_items"
  add_foreign_key "dashboard_item_sources", "sources"
  add_foreign_key "dashboard_items", "dashboards"
  add_foreign_key "devices", "dashboards"
  add_foreign_key "frames", "devices"
end
