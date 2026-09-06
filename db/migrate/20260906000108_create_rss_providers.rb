class CreateRssProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :rss_providers do |t|
      t.string :feed_url
      t.integer :max_items, default: 10

      t.timestamps
    end
  end
end
