class CreateFrames < ActiveRecord::Migration[8.1]
  def change
    create_table :frames do |t|
      t.references :device, null: false, foreign_key: true
      t.string :checksum
      t.integer :byte_size
      t.string :format, default: "bmp"
      t.binary :data
      t.datetime :rendered_at

      t.timestamps
    end

    add_index :frames, [ :device_id, :rendered_at ]
  end
end
