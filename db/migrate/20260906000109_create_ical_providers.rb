class CreateIcalProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :ical_providers do |t|
      t.string :ical_url
      t.boolean :include_all_day, default: true

      t.timestamps
    end
  end
end
