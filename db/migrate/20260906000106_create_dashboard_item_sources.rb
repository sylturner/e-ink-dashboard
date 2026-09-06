class CreateDashboardItemSources < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_item_sources do |t|
      t.references :dashboard_item, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :dashboard_item_sources, [ :dashboard_item_id, :source_id ],
              unique: true, name: "index_dis_on_item_and_source"
  end
end
