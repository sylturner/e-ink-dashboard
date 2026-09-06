class CreateDeviceDashboards < ActiveRecord::Migration[8.1]
  def up
    create_table :device_dashboards do |t|
      t.references :device,    null: false, foreign_key: true
      t.references :dashboard, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :device_dashboards, [ :device_id, :dashboard_id ],
              unique: true, name: "index_device_dashboards_on_device_and_dashboard"

    # Every device that already pointed at a dashboard is now assigned to
    # it. devices.dashboard_id is kept, but narrows in meaning: it is the
    # one of the assigned dashboards currently on the panel.
    execute <<~SQL
      INSERT INTO device_dashboards (device_id, dashboard_id, position, created_at, updated_at)
      SELECT id, dashboard_id, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM devices
      WHERE dashboard_id IS NOT NULL
    SQL
  end

  def down
    drop_table :device_dashboards
  end
end
