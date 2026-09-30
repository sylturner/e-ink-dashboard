# The declarative description of every dashboard component: which layouts
# it offers, which source types it accepts, which settings it takes, and
# which parts each layout draws.
#
# The inspector form, the DashboardItem validations and the render
# partials all read from here, so adding a layout, a setting or a part is
# a one-place change.
class Component
  # `hint` is a line the inspector shows under the field. A `default` can
  # be a lambda, for one worked out when the tile is first edited (today's
  # date): the form shows it, and saving keeps it.
  Setting = Struct.new(:key, :type, :label, :default, :options, :views, :hint,
                       keyword_init: true) do
    # Settings round-trip through a JSON column and an HTML form, so they
    # come back as strings. Cast on the way out so partials can trust the
    # type the registry declared.
    def cast(value)
      return (default.respond_to?(:call) ? default.call : default) if value.nil? || value == ""

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

  # What a checklist tile does with the items that are done: strikes them
  # through where they are, strikes them and moves them to the bottom, or
  # leaves them off.
  CHECKLIST_DONE_ITEMS = %w[strike bottom hide].freeze

  # A QR code tile's px per module (see note's qr_code part). Larger than a
  # note's, since the code is the whole tile.
  QR_SIZES = { "small" => 3, "medium" => 4, "large" => 6 }.freeze

  # A number drawn as the tile's main thing: a countdown's.
  NUMBER_SIZES = { "small" => "t-lg", "medium" => "t-xl", "large" => "t-xxl" }.freeze

  # A data tile's lines. Medium is the tile's own text size (its look).
  DATA_LINE_SIZES = { "small" => "t-xs", "medium" => nil, "large" => "t-md" }.freeze

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
        Setting.new(key: "masthead_font", type: :font, label: "Name font", default: "jacquard", views: %w[custom],
                    options: -> { NewspaperStyle.masthead_options }),
        Setting.new(key: "headline_font", type: :font, label: "Headline font", default: "jersey", views: %w[custom],
                    options: -> { NewspaperFont.options }),
        Setting.new(key: "subhead_font", type: :font, label: "Small headline font", default: "pixel_operator_bold",
                    views: %w[custom], options: -> { NewspaperFont.options }),
        Setting.new(key: "text_font", type: :font, label: "Text font", default: "pixantiqua", views: %w[custom],
                    options: -> { NewspaperFont.options }),
        Setting.new(key: "label_font", type: :font, label: "Label font", default: "pixeloid_sans", views: %w[custom],
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

    # A list checked off from its phone page (ChecklistProvider). Either
    # layout lists every item; columns flows them into several.
    "checklist" => {
      label: "Checklist",
      views: { "list" => "List", "columns" => "Columns" },
      source_types: %w[ChecklistProvider],
      multi_source: false,
      settings: [
        Setting.new(key: "done_items", type: :select, label: "Done items", default: "strike",
                    options: -> { CHECKLIST_DONE_ITEMS.map { [ I18n.t("components.checklist.done_items.#{it}"), it ] } }),
        Setting.new(key: "column_count", type: :integer, label: "Columns", default: 2, views: %w[columns])
      ],
      # A checkbox's edge in px, and the QR code's px per module (see note).
      parts: %w[list columns].index_with do
        [
          Part.new(key: "checkboxes", sizes: { "small" => 8, "medium" => 12, "large" => 16 }),
          Part.new(key: "progress", default: false),
          Part.new(key: "qr_code", default: false, sizes: { "small" => 2, "medium" => 3, "large" => 4 })
        ]
      end
    },

    # Days until a date, or since it once it's past (Countdown), as a big
    # number or in a sentence.
    "countdown" => {
      label: "Countdown",
      views: { "big_number" => "Big number", "sentence" => "Sentence" },
      source_types: [],
      settings: [
        Setting.new(key: "label", type: :string, label: "Counting down to", default: "",
                    hint: "A name, like Christmas: “12 days until Christmas”."),
        Setting.new(key: "date", type: :date, label: "Date", default: ""),
        Setting.new(key: "time", type: :time, label: "Time (optional)", default: "",
                    hint: "Used when counting in hours. Blank is the start of the day."),
        Setting.new(key: "unit", type: :select, label: "Count in", default: "days",
                    options: -> { Countdown::UNITS.map { [ I18n.t("components.countdown.units.#{it}"), it ] } })
      ],
      parts: {
        "big_number" => [ Part.new(key: "number", sizes: NUMBER_SIZES, default_size: "large"), Part.new(key: "label") ],
        "sentence" => [ Part.new(key: "sentence", sizes: TYPE_SIZES) ]
      }
    },

    # A list that takes a turn each day or week (Rotation): a chore wheel,
    # whose turn it is, a quote of the day.
    "rotation" => {
      label: "Rotation",
      views: { "current" => "Current entry", "list" => "Whole list" },
      source_types: [],
      settings: [
        Setting.new(key: "entries", type: :text, label: "Entries", default: "",
                    hint: "One per line."),
        Setting.new(key: "period", type: :select, label: "Moves on", default: "daily",
                    options: -> { Rotation::PERIODS.map { [ I18n.t("components.rotation.periods.#{it}"), it ] } }),
        Setting.new(key: "start", type: :date, label: "First entry's day", default: -> { Date.current.iso8601 },
                    hint: "The first entry shows on this day, or in its week, and the list moves on from there.")
      ],
      parts: {
        "current" => [ Part.new(key: "entry", sizes: TYPE_SIZES),
                       Part.new(key: "upcoming", default: false) ]
      }
    },

    # A QR code a phone's camera opens: a Wi-Fi network to join
    # (WifiNetwork), or any link or text.
    "qr_code" => {
      label: "QR code",
      views: { "wifi" => "Wi-Fi network", "link" => "Link or text" },
      source_types: [],
      settings: [
        Setting.new(key: "ssid", type: :string, label: "Network name", default: "", views: %w[wifi]),
        Setting.new(key: "password", type: :password, label: "Password", default: "", views: %w[wifi],
                    hint: "Kept with the tile, where anyone who can open this app can read it."),
        Setting.new(key: "security", type: :select, label: "Security", default: "WPA", views: %w[wifi],
                    options: -> { WifiNetwork::SECURITIES.map { [ I18n.t("components.qr_code.security.#{it}"), it ] } }),
        Setting.new(key: "hidden", type: :boolean, label: "Hidden network", default: false, views: %w[wifi]),
        Setting.new(key: "text", type: :text, label: "Link or text", default: "", views: %w[link]),
        Setting.new(key: "caption", type: :string, label: "Caption", default: "")
      ],
      parts: {
        "wifi" => [ Part.new(key: "qr_code", sizes: QR_SIZES), Part.new(key: "network"),
                    Part.new(key: "password", default: false) ],
        "link" => [ Part.new(key: "qr_code", sizes: QR_SIZES), Part.new(key: "text", default: false) ]
      }
    },

    # Values from a JSON source (JsonProvider), drawn through the tokens of
    # its lines (DataTemplate): once, or for each entry of a list in the
    # data. Or one value, big.
    "data" => {
      label: "Data",
      views: { "lines" => "Lines", "big_stat" => "Big number" },
      source_types: %w[JsonProvider],
      multi_source: false,
      settings: [
        Setting.new(key: "lines", type: :text, label: "Lines", default: "", views: %w[lines],
                    hint: "One per line, with {paths} into the data: {state}, {attributes.temperature}. " \
                          "A line whose values are all empty isn't drawn."),
        Setting.new(key: "list_path", type: :string, label: "Repeat for each of", default: "", views: %w[lines],
                    hint: "A list in the data, like departures, or $ when the data is itself a list. " \
                          "Its entries' paths start inside each one. Blank draws the lines once."),
        Setting.new(key: "list_limit", type: :integer, label: "Most entries", default: 5, views: %w[lines]),
        Setting.new(key: "value", type: :string, label: "Number", default: "", views: %w[big_stat],
                    hint: "A {path} into the data, with any text around it: {state}°."),
        Setting.new(key: "caption", type: :string, label: "Under it", default: "", views: %w[big_stat],
                    hint: "Text and {paths}, like {attributes.friendly_name}.")
      ],
      parts: {
        "lines" => [ Part.new(key: "lines", sizes: DATA_LINE_SIZES) ],
        "big_stat" => [ Part.new(key: "value", sizes: NUMBER_SIZES, default_size: "medium"), Part.new(key: "caption") ]
      }
    },

    # A photo uploaded in the inspector (an :image setting), filling the
    # tile or shown whole.
    "photo" => {
      label: "Photo",
      views: { "fill" => "Fill the tile", "fit" => "Whole photo" },
      source_types: [],
      settings: [
        Setting.new(key: "image", type: :image, label: "Photo", default: ""),
        Setting.new(key: "caption", type: :string, label: "Caption", default: "")
      ],
      parts: %w[fill fit].index_with { [ Part.new(key: "caption") ] }
    },

    # Text written in the inspector: Markdown, drawn as a note is, or
    # plain. Both fill PanelTokensHelper's tokens, such as {{CURRENT_TIME}}.
    "text" => {
      label: "Text",
      views: { "formatted" => "Formatted", "plain" => "Plain text" },
      source_types: [],
      settings: [
        Setting.new(key: "body", type: :markdown, label: "Text", default: "")
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

    # The kinds whose settings hold Markdown, in a :markdown setting keyed
    # "body" (MarkdownImages looks there for uploaded images).
    def markdown_kinds
      KINDS.select { |kind| settings(kind).any? { it.type == :markdown } }
    end

    # The kinds whose settings hold an uploaded image, in an :image
    # setting: the blob's signed id (MarkdownImages keeps those blobs).
    def image_settings
      KINDS.to_h { |kind| [ kind, settings(kind).select { it.type == :image }.map(&:key) ] }.compact_blank
    end

    def source_types(kind)
      find(kind)&.fetch(:source_types, []) || []
    end

    def multi_source?(kind)
      find(kind)&.dig(:multi_source) ? true : false
    end
  end
end
