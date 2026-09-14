# Calendar's show_times and news' show_source were settings shared by
# every layout. They are parts now, which each layout keeps for itself
# (Component::Part), so copy a saved value into every layout that draws
# it.
class MoveTileTogglesIntoParts < ActiveRecord::Migration[8.1]
  # kind => { old setting => [part, layouts that draw it] }. Spelled out
  # here rather than read from Component, which will keep changing.
  MOVES = {
    "calendar" => { "show_times" => [ "times", %w[today tomorrow next_days week next_events] ] },
    "news"     => { "show_source" => [ "source", %w[headlines] ] }
  }.freeze

  class Item < ActiveRecord::Base
    self.table_name = "dashboard_items"
  end

  def up
    each_item do |item, settings|
      MOVES.fetch(item.kind).each do |old_key, (part, views)|
        next unless settings.key?(old_key)

        value = settings.delete(old_key)
        parts = settings["parts"] = settings["parts"].is_a?(Hash) ? settings["parts"] : {}
        views.each { |view| (parts[view] ||= {})[part] = value }
      end
    end
  end

  def down
    each_item do |item, settings|
      parts = settings["parts"]
      next unless parts.is_a?(Hash)

      MOVES.fetch(item.kind).each do |old_key, (part, views)|
        # Prefer the value of the layout the tile is showing.
        values = views.index_with { |view| parts[view].delete(part) if parts[view].is_a?(Hash) }
        value  = values[item.view].nil? ? values.values.compact.first : values[item.view]
        settings[old_key] = value unless value.nil?
      end

      parts.delete_if { |_, choices| choices == {} }
      settings.delete("parts") if parts.empty?
    end
  end

  private

    def each_item
      Item.where(kind: MOVES.keys).find_each do |item|
        settings = (item.settings || {}).deep_dup
        yield item, settings
        item.update_columns(settings: settings) unless settings == item.settings
      end
    end
end
