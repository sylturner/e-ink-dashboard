class AddServerUrlToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :server_url, :string
  end
end
