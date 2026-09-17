# The headline template a new news tile starts with (NewsTemplate). Nil
# until it's first saved, which reads as NewsTemplate::DEFAULT.
class AddNewsTemplateToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :news_template, :json
  end
end
