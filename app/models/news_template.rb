# How a news tile draws each headline: an optional picture beside or
# above the text, then up to LINE_COUNT lines. Each line shows one of the
# item's named fields, or a custom format of tokens, at a size and a
# number of lines it may wrap to.
#
# A tile keeps its own under settings["template"], and a new tile starts
# with the app's (AppSetting#news_template). Both arrive from forms, so
# .from accepts anything and keeps only what it recognizes.
class NewsTemplate
  # The named tokens, in the order a line's field select lists them. Any
  # other token is a path into the item's fields (Feed#fields).
  FIELDS = %w[title summary author source date age].freeze
  NONE   = "none".freeze
  CUSTOM = "custom".freeze

  PLACEMENTS = %w[none left right above].freeze

  # Image edges in px, on the 8px grid. Beside the text, a square; above
  # it, the height of a picture as wide as the row.
  IMAGE_SIDES   = { "small" => 48, "medium" => 80, "large" => 120 }.freeze
  IMAGE_HEIGHTS = { "small" => 80, "medium" => 120, "large" => 160 }.freeze

  # render.css type classes. Medium draws at the theme's body size.
  LINE_SIZES = { "small" => "t-xs", "medium" => nil, "large" => "t-md", "extra_large" => "t-lg" }.freeze

  # render.css has t-clip-1 to t-clip-4.
  CLAMPS = (1..4).freeze

  LINE_COUNT    = 3
  FORMAT_LENGTH = 200

  TOKEN = /\{([^{}\s]+)\}/

  # What a line's leftover separators look like once its tokens are
  # empty: "The Paper · " or " · 2h".
  DANGLING = /\A[\s·•|,\-–—]+|[\s·•|,\-–—]+\z/

  Image = Data.define(:placement, :size) do
    def shown?
      placement != NONE
    end

    # [width, height] in px, or width nil for a picture as wide as its row.
    def dimensions
      placement == "above" ? [ nil, IMAGE_HEIGHTS.fetch(size) ] : [ IMAGE_SIDES.fetch(size) ] * 2
    end
  end

  Line = Data.define(:field, :format, :size, :clamp) do
    def shown?
      field != NONE && tokens.present?
    end

    def custom?
      field == CUSTOM
    end

    # The format this line draws, whether it was picked or written.
    def tokens
      custom? ? format.to_s : "{#{field}}"
    end

    def size_class
      LINE_SIZES.fetch(size)
    end
  end

  # A tile drawn as before templates: the title, wrapped to two lines.
  DEFAULT = {
    "image" => { "placement" => NONE, "size" => "small" },
    "lines" => [
      { "field" => "title", "format" => "", "size" => "medium", "clamp" => 2 },
      { "field" => NONE, "format" => "", "size" => "small", "clamp" => 1 },
      { "field" => NONE, "format" => "", "size" => "small", "clamp" => 1 }
    ]
  }.freeze

  attr_reader :image, :lines

  def self.default
    from(DEFAULT)
  end

  def self.from(value)
    value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
    value = {} unless value.is_a?(Hash)
    new(value.deep_stringify_keys)
  end

  def initialize(hash)
    image  = hash["image"].is_a?(Hash) ? hash["image"] : {}
    @image = Image.new(placement: pick(image["placement"], PLACEMENTS, DEFAULT.dig("image", "placement")),
                       size: pick(image["size"], IMAGE_SIDES.keys, DEFAULT.dig("image", "size")))

    @lines = Array.new(LINE_COUNT) { |index| line(line_hashes(hash["lines"])[index], DEFAULT["lines"][index]) }
  end

  def to_h
    { "image" => image.to_h.stringify_keys, "lines" => lines.map { it.to_h.stringify_keys } }
  end

  def ==(other)
    other.is_a?(NewsTemplate) && to_h == other.to_h
  end

  # Fills a line's tokens from a NewsFeed entry. `named` resolves the
  # named tokens that need a view (a date on the panel's clock); anything
  # else is read from the entry, then its fields. Nil when nothing
  # resolved, so a line of empty tokens isn't drawn as bare separators.
  def self.fill(tokens, entry, named: {})
    fields   = entry["fields"].is_a?(Hash) ? entry["fields"] : {}
    resolved = false

    text = tokens.gsub(TOKEN) do
      name  = $1
      value = named.key?(name) ? named[name] : (FIELDS.include?(name) ? entry[name] : fields[name])
      resolved ||= value.present?
      value.to_s
    end

    text.gsub(DANGLING, "").squish.presence if resolved
  end

  private

    def pick(value, allowed, fallback)
      allowed.include?(value.to_s) ? value.to_s : fallback
    end

    # A form sends lines as { "0" => {...}, "1" => {...} }; JSON as a list.
    def line_hashes(lines)
      lines = lines.sort_by { |key, _| key.to_i }.map(&:last) if lines.is_a?(Hash)
      Array(lines).map { it.is_a?(Hash) ? it : {} }
    end

    def line(hash, fallback)
      hash ||= fallback
      clamp  = hash["clamp"].to_i

      Line.new(field: pick(hash["field"], [ NONE, *FIELDS, CUSTOM ], fallback["field"]),
               format: hash["format"].to_s.squish.first(FORMAT_LENGTH),
               size: pick(hash["size"], LINE_SIZES.keys, fallback["size"]),
               clamp: CLAMPS.cover?(clamp) ? clamp : fallback["clamp"])
    end
end
