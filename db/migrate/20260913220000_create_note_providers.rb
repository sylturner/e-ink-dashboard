class CreateNoteProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :note_providers do |t|
      t.text :body
      t.timestamps
    end
  end
end
