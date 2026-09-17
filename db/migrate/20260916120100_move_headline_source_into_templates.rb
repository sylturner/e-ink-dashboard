# A headline's feed name was a part of the headlines layout. It's a line
# of the tile's headline template now (NewsTemplate), so give every news
# tile a template: the title as before, then the feed name on a small
# second line where the part was on.
class MoveHeadlineSourceIntoTemplates < ActiveRecord::Migration[8.1]
  # Spelled out here rather than read from NewsTemplate, which will keep
  # changing.
  TITLE  = { "field" => "title", "format" => "", "size" => "medium", "clamp" => 2 }.freeze
  SOURCE = { "field" => "source", "format" => "", "size" => "small", "clamp" => 1 }.freeze
  NONE   = { "field" => "none", "format" => "", "size" => "small", "clamp" => 1 }.freeze

  class Item < ActiveRecord::Base
    self.table_name = "dashboard_items"
  end

  def up
    each_news_item do |settings|
      next if settings.key?("template")

      parts  = settings["parts"].is_a?(Hash) ? settings["parts"] : {}
      source = parts["headlines"].is_a?(Hash) ? parts["headlines"].delete("source") : nil
      parts.delete("headlines") if parts["headlines"] == {}
      settings.delete("parts") if parts == {}

      shown = ActiveModel::Type::Boolean.new.cast(source)
      settings["template"] = {
        "image" => { "placement" => "none", "size" => "small" },
        "lines" => [ TITLE, shown ? SOURCE : NONE, NONE ]
      }
    end
  end

  # Keeps the feed name when a line still draws it, and drops the rest of
  # the template, which the part has no way to say.
  def down
    each_news_item do |settings|
      template = settings.delete("template")
      next unless template.is_a?(Hash)

      source = Array(template["lines"]).any? { it.is_a?(Hash) && it["field"] == "source" }
      next unless source

      parts = settings["parts"] = settings["parts"].is_a?(Hash) ? settings["parts"] : {}
      (parts["headlines"] ||= {})["source"] = "1"
    end
  end

  private

    def each_news_item
      Item.where(kind: "news").find_each do |item|
        settings = (item.settings || {}).deep_dup
        yield settings
        item.update_columns(settings: settings) unless settings == item.settings
      end
    end
end
