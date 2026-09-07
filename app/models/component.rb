# The declarative description of every dashboard component: which layouts
# it offers, which source types it accepts, and which settings it takes.
#
# Both the inspector form and the DashboardItem validations read from
# here, so adding a layout or a setting is a one-place change.
class Component
  Setting = Struct.new(:key, :type, :label, :default, :options, :views,
                       keyword_init: true) do
    # Settings round-trip through a JSON column and an HTML form, so they
    # come back as strings. Cast on the way out so partials can trust the
    # type the registry declared.
    def cast(value)
      return default if value.nil? || value == ""

      case type
      when :integer then value.to_i
      when :boolean then ActiveModel::Type::Boolean.new.cast(value)
      else value
      end
    end
  end

  REGISTRY = {
    "clock" => {
      label: "Clock",
      views: { "time" => "Time and date" },
      source_types: [],
      settings: []
    },

    "calendar" => {
      label: "Calendar",
      views: {
        "today"       => "Today",
        "tomorrow"    => "Tomorrow",
        "next_days"   => "Next X days",
        "week"        => "This week",
        "month"       => "Month grid",
        "next_events" => "Next X events"
      },
      source_types: %w[IcalProvider],
      multi_source: true,
      settings: [
        Setting.new(key: "day_count", type: :integer, label: "Days ahead",
                    default: 3, views: %w[next_days]),
        Setting.new(key: "event_limit", type: :integer, label: "Max events",
                    default: 6, views: %w[today tomorrow next_events]),
        Setting.new(key: "show_times", type: :boolean, label: "Show times",
                    default: true, views: %w[today tomorrow next_days week next_events])
      ]
    },

    "weather" => {
      label: "Weather",
      views: {
        "current"  => "Right now",
        "forecast" => "Daily forecast",
        "hourly"   => "Hourly strip"
      },
      source_types: %w[WeatherProvider],
      multi_source: false,
      settings: [
        Setting.new(key: "day_count", type: :integer, label: "Days shown",
                    default: 5, views: %w[forecast]),
        Setting.new(key: "hour_count", type: :integer, label: "Hours shown",
                    default: 6, views: %w[hourly])
      ]
    },

    "news" => {
      label: "News",
      views: {
        "headlines" => "Headlines",
        "images" => "Images"
      },
      source_types: %w[RssProvider],
      multi_source: true,
      settings: [
        Setting.new(key: "event_limit", type: :integer, label: "Headlines",
                    default: 4),
        Setting.new(key: "show_source", type: :boolean, label: "Show feed name",
                    default: false)
      ]
    },

    "text" => {
      label: "Text",
      views: { "plain" => "Plain text" },
      source_types: [],
      settings: [
        Setting.new(key: "body", type: :text, label: "Text", default: "")
      ]
    }
  }.freeze

  KINDS = REGISTRY.keys.freeze

  class << self
    def find(kind)
      REGISTRY[kind.to_s]
    end

    def label(kind)
      find(kind)&.fetch(:label, kind) || kind
    end

    def views(kind)
      find(kind)&.fetch(:views, {}) || {}
    end

    def default_view(kind)
      views(kind).keys.first
    end

    def settings(kind, view: nil)
      all = find(kind)&.fetch(:settings, []) || []
      return all if view.blank?

      all.select { |s| s.views.blank? || s.views.include?(view.to_s) }
    end

    def setting(kind, key)
      settings(kind).find { |s| s.key == key.to_s }
    end

    def source_types(kind)
      find(kind)&.fetch(:source_types, []) || []
    end

    def multi_source?(kind)
      find(kind)&.dig(:multi_source) ? true : false
    end
  end
end
