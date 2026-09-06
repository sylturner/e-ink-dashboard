class CreateDashboardItems < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_items do |t|
      t.references :dashboard, null: false, foreign_key: true
      t.string :kind
      t.string :view
      t.string :title
      t.integer :col, default: 1
      t.integer :row, default: 1
      t.integer :col_span, default: 2
      t.integer :row_span, default: 2
      t.integer :position, default: 0
      t.json :settings, default: {}
      t.boolean :visible, default: true

      t.timestamps
    end

    add_index :dashboard_items, [ :dashboard_id, :position ]
  end
end
