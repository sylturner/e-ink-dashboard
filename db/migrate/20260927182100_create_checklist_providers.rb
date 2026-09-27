class CreateChecklistProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_providers do |t|
      # [{ "id", "text", "done_at" }], in order.
      t.json :items, null: false, default: []
      t.string :reset, null: false, default: "never"
      t.timestamps
    end
  end
end
