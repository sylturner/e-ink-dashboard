class CreateDashboards < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboards do |t|
      t.string :name
      t.string :theme, default: "default"
      t.integer :grid_columns, default: 8
      t.integer :grid_rows, default: 8

      t.timestamps
    end
  end
end
