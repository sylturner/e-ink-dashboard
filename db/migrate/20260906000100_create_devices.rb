class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :name
      t.string :token
      t.references :dashboard, null: true, foreign_key: true
      t.integer :width, default: 800
      t.integer :height, default: 480
      t.integer :bit_depth, default: 1
      t.string :image_format, default: "bmp"
      t.integer :rotation, default: 0
      t.integer :refresh_seconds, default: 300
      t.integer :night_refresh_seconds, default: 3600
      t.integer :active_from_hour, default: 6
      t.integer :active_until_hour, default: 23
      t.string :time_zone
      t.datetime :last_seen_at
      t.integer :battery_percent
      t.decimal :battery_voltage, precision: 4, scale: 2
      t.integer :wifi_rssi
      t.string :firmware_version
      t.datetime :refresh_requested_at

      t.timestamps
    end
    add_index :devices, :token, unique: true
  end
end
