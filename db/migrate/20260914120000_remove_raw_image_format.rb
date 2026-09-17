# Only the old ESP32 sketch could read raw frames. Panels now speak TRMNL's
# API, whose firmware decodes a BMP at 800x480 and a PNG at any size.
class RemoveRawImageFormat < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE devices
      SET image_format = CASE WHEN width = 800 AND height = 480 THEN 'bmp' ELSE 'png' END
      WHERE image_format = 'raw' OR (image_format = 'bmp' AND NOT (width = 800 AND height = 480))
    SQL

    # Each panel renders a new frame at its next check-in.
    execute "DELETE FROM frames WHERE format = 'raw'"
  end

  def down
    # Nothing to restore: the old format is gone from the app.
  end
end
