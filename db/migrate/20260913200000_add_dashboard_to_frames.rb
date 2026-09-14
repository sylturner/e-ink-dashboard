# A frame remembers the dashboard it was rendered from, so the dashboard
# list can show it as the dashboard's thumbnail.
class AddDashboardToFrames < ActiveRecord::Migration[8.1]
  def up
    add_reference :frames, :dashboard, foreign_key: true

    # Existing frames are most likely of the dashboard their panel shows
    # now, so the list has thumbnails before the next render.
    execute <<~SQL
      UPDATE frames
      SET dashboard_id = (SELECT dashboard_id FROM devices WHERE devices.id = frames.device_id)
    SQL
  end

  def down
    remove_reference :frames, :dashboard, foreign_key: true
  end
end
