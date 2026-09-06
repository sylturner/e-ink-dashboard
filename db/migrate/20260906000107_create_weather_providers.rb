class CreateWeatherProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_providers do |t|
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :units, default: "imperial"
      t.string :time_zone

      t.timestamps
    end
  end
end
