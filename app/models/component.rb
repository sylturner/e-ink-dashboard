# The declarative description of every dashboard component: which layouts
# it offers, which source types it accepts, which settings it takes, and
# which parts each layout draws.
#
# The inspector form, the DashboardItem validations and the render
# partials all read from here, so adding a layout, a setting or a part is
# a one-place change.
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

  # The sizes a sized part offers, smallest first.
  SIZE_NAMES = %w[small medium large].freeze

  # Something a layout draws that can be shown or hidden: the weather
  # icon, the high and low, an event's time. Parts are declared per
  # layout, because layouts draw different things and start with
  # different ones showing. Every default draws the layout as it was
  # before parts existed.
  #
  # `sizes` maps each of SIZE_NAMES to what the partial draws at that
  # size: an icon's edge in px, or a type class from render.css. Keep px
  # to multiples of 8 so a glyph stays on the 1-bit panel's pixel grid.
  Part = Struct.new(:key, :default, :sizes, :default_size, keyword_init: true) do
    def initialize(key:, default: true, sizes: nil, default_size: "medium")
      super
    end

    def sized?
      sizes.present?
    end

    # Parts round-trip through checkboxes, so they come back as "1" or
    # "0". Blank means the layout has never been saved with this part.
    def shown?(value)
      return default if value.nil? || value == ""

      ActiveModel::Type::Boolean.new.cast(value)
    end

    # A size this part offers, or its default.
    def size_name(value)
      sizes&.key?(value.to_s) ? value.to_s : default_size
    end

    # What the partial draws at a size.
    def size(name)
      raise ArgumentError, "the #{key} part has no sizes" unless sized?

      sizes.fetch(size_name(name))
    end
  end

  # A sized line of text, drawn with render.css's type classes.
  TYPE_SIZES = { "small" => "t-md", "medium" => "t-lg", "large" => "t-xl" }.freeze

  # The calendar layouts that list events, as opposed to the month grid.
  CALENDAR_LISTS = %w[today tomorrow next_days week next_events].freeze

  REGISTRY = {
    "clock" => {
      label: "Clock",
      views: { "time" => "Time and date" },
      source_types: [],
      settings: [],
      parts: {
        "time" => [
          Part.new(key: "time", sizes: TYPE_SIZES, default_size: "large"),
          Part.new(key: "date")
        ]
      }
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
                    default: 6, views: %w[today tomorrow next_events])
      ],
      parts: CALENDAR_LISTS.index_with { [ Part.new(key: "times"), Part.new(key: "tags") ] }.merge(
        "month" => [ Part.new(key: "weekday_header"), Part.new(key: "event_dots") ]
      )
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
      ],
      parts: {
        "current" => [
          Part.new(key: "icon", sizes: { "small" => 32, "medium" => 64, "large" => 96 }),
          Part.new(key: "temperature", sizes: TYPE_SIZES),
          Part.new(key: "condition"),
          Part.new(key: "feels_like"),
          Part.new(key: "high_low"),
          Part.new(key: "precip"),
          Part.new(key: "humidity", default: false),
          Part.new(key: "sun", default: false)
        ],
        "forecast" => [
          Part.new(key: "icon", sizes: { "small" => 16, "medium" => 24, "large" => 32 }),
          Part.new(key: "condition"),
          Part.new(key: "high_low"),
          Part.new(key: "precip", default: false)
        ],
        "hourly" => [
          Part.new(key: "icon", sizes: { "small" => 24, "medium" => 32, "large" => 48 }),
          Part.new(key: "condition"),
          Part.new(key: "temperature"),
          Part.new(key: "precip", default: false)
        ]
      }
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
                    default: 4)
      ],
      # Headlines are drawn from the tile's NewsTemplate, which the
      # inspector edits in place of parts.
      templates: %w[headlines]
    },

    # A whole front page in one tile, meant to fill the grid: a masthead
    # with a weather ear, a lead story with its photo, headlines around
    # it, and a box of upcoming events. Reads its first weather source and
    # merges every feed and every calendar. Each layout is a type of paper
    # (NewspaperStyle).
    "newspaper" => {
      label: "Newspaper",
      views: {
        "broadsheet" => "Serious broadsheet",
        "tabloid"    => "Tabloid",
        "zine"       => "Punk zine",
        "patriot"    => "Patriot",
        "hacker"     => "90s hacker",
        "wizard"     => "Wizarding gazette",
        "mac"        => "Classic Mac",
        "windows"    => "Classic Windows",
        "cde"        => "CDE",
        "custom"     => "Custom"
      },
      source_types: %w[RssProvider WeatherProvider IcalProvider],
      multi_source: true,
      settings: [
        Setting.new(key: "name", type: :string, label: "Paper name", default: "The Daily Dashboard"),
        Setting.new(key: "motto", type: :string, label: "Motto (blank for the paper's own)", default: ""),
        Setting.new(key: "story_count", type: :integer, label: "Most briefs", default: 12),
        Setting.new(key: "event_hours", type: :integer, label: "Hours of upcoming events", default: 36),
        Setting.new(key: "layout", type: :select, label: "Arrangement", default: "broadsheet", views: %w[custom],
                    options: -> { NewspaperStyle::LAYOUTS.map { [ it.titleize, it ] } }),
        Setting.new(key: "caps", type: :boolean, label: "Headlines in capitals", default: false, views: %w[custom]),
        Setting.new(key: "masthead_font", type: :select, label: "Name font", default: "jacquard", views: %w[custom],
                    options: -> { NewspaperStyle.masthead_options }),
        Setting.new(key: "headline_font", type: :select, label: "Headline font", default: "jersey", views: %w[custom],
                    options: -> { NewspaperFont.options }),
        Setting.new(key: "subhead_font", type: :select, label: "Small headline font", default: "pixel_operator_bold",
                    views: %w[custom], options: -> { NewspaperFont.options }),
        Setting.new(key: "text_font", type: :select, label: "Text font", default: "pixantiqua", views: %w[custom],
                    options: -> { NewspaperFont.options }),
        Setting.new(key: "label_font", type: :select, label: "Label font", default: "pixeloid_sans", views: %w[custom],
                    options: -> { NewspaperFont.options })
      ],
      parts: NewspaperStyle::KEYS.index_with do
        [ Part.new(key: "weather"), Part.new(key: "dateline"), Part.new(key: "photos"), Part.new(key: "events"),
          Part.new(key: "bylines"), Part.new(key: "summaries") ]
      end
    },

    "note" => {
      label: "Note",
      views: { "formatted" => "Formatted" },
      source_types: %w[NoteProvider],
      multi_source: false,
      settings: [],
      parts: {
        # A QR code of the note's phone page. Its sizes are px per module
        # rather than a glyph's edge: any whole number keeps every module on
        # the pixel grid.
        "formatted" => [
          Part.new(key: "qr_code", default: false, sizes: { "small" => 2, "medium" => 3, "large" => 4 })
        ]
      }
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

    # The parts a layout draws, in the order the inspector lists them.
    def parts(kind, view)
      find(kind)&.dig(:parts, view.to_s) || []
    end

    def part(kind, view, key)
      parts(kind, view).find { |p| p.key == key.to_s }
    end

    # For the render partials: a part they draw has to be declared, so a
    # typo fails loudly instead of quietly hiding something.
    def part!(kind, view, key)
      part(kind, view, key) or
        raise ArgumentError, "#{label(kind)} #{view} declares no #{key} part"
    end

    # The layouts drawn from a NewsTemplate.
    def templates(kind)
      find(kind)&.fetch(:templates, []) || []
    end

    def source_types(kind)
      find(kind)&.fetch(:source_types, []) || []
    end

    def multi_source?(kind)
      find(kind)&.dig(:multi_source) ? true : false
    end
  end
end
