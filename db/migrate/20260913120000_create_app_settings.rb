class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.string :time_zone, null: false, default: "Etc/UTC"
      t.string :units, null: false, default: "imperial"
      t.string :clock, null: false, default: "12h"
      t.string :week_start, null: false, default: "sunday"
      t.integer :refresh_seconds, null: false, default: 900
      t.integer :night_refresh_seconds, null: false, default: 3600
      t.integer :active_from_hour, null: false, default: 6
      t.integer :active_until_hour, null: false, default: 23
      t.timestamps
    end

    # Enrollment used to save the server's zone, which was always UTC, onto
    # every panel. Clearing it lets those panels follow the app's zone.
    up_only { execute "UPDATE devices SET time_zone = NULL WHERE time_zone = 'UTC'" }
  end
end
