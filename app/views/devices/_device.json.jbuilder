json.extract! device, :id, :name, :token, :dashboard_id, :width, :height, :bit_depth, :image_format, :rotation, :refresh_seconds, :night_refresh_seconds, :active_from_hour, :active_until_hour, :time_zone, :last_seen_at, :battery_percent, :battery_voltage, :wifi_rssi, :firmware_version, :refresh_requested_at, :created_at, :updated_at
json.url device_url(device, format: :json)
