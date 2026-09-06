class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.string :name
      t.references :providable, polymorphic: true, null: false
      t.integer :refresh_seconds, default: 900
      t.json :payload, default: {}
      t.datetime :fetched_at
      t.datetime :attempted_at
      t.string :last_error
      t.integer :failure_count, default: 0

      t.timestamps
    end
  end
end
