class CreateJsonProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :json_providers do |t|
      t.string :url, null: false
      # "Name: value", one per line: an API key, a bearer token.
      t.text :headers
      t.timestamps
    end
  end
end
