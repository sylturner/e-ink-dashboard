# How a tile's card looks, whatever it draws: its border, its header, its
# padding, alignment and type. The same choices for every component, kept
# in the tile's settings["look"] and drawn as .look--* classes on the card
# (render.css).
#
# Every choice starts blank, which means the dashboard's theme decides:
# a tile nobody has restyled renders exactly as it did before.
class TileLook
  CHOICES = {
    "border"  => %w[none thin thick double rounded],
    "header"  => %w[inverted rule plain],
    "padding" => %w[none roomy spacious],
    "align"   => %w[left center right middle],
    "scale"   => %w[small large]
  }.freeze

  # The type sizes a font is set near, in px, by scale. Pixel fonts are only
  # crisp at a whole multiple of their grid, so a font is set at the
  # multiple nearest these (#type).
  TARGETS = { "small" => 8, nil => 16, "large" => 24 }.freeze

  # A header is always set near the theme's header size.
  HEADER_TARGET = 16

  FONTS = %w[font header_font].freeze

  def initialize(hash)
    hash = hash.is_a?(Hash) ? hash.stringify_keys : {}

    @choices = CHOICES.to_h { |key, allowed| [ key, hash[key].presence_in(allowed) ] }
    @invert  = ActiveModel::Type::Boolean.new.cast(hash["invert"]) ? true : false
    @fonts   = FONTS.to_h { [ it, NewspaperFont.find(hash[it].presence)&.key ] }
  end

  def [](key)
    key = key.to_s
    return @invert if key == "invert"

    @choices.key?(key) ? @choices[key] : @fonts[key]
  end

  def invert? = @invert

  def default?
    @choices.values.none? && !@invert && @fonts.values.none?
  end

  # The card's classes, in a fixed order so the render is stable.
  def classes
    [
      *@choices.filter_map { |key, value| "look--#{key}-#{value}" if value },
      ("look--invert" if @invert),
      *type_classes
    ].compact
  end

  # The rules the tiles' pixel fonts need: each face once, and a class
  # for each font at each size it's set. Faces render.css already declares
  # aren't embedded again.
  def self.css(looks)
    types = looks.flat_map(&:types).uniq
    return "" if types.empty?

    faces = types.map { it[:cut] }.uniq(&:key).reject(&:shared?).map(&:face)

    rules = types.map do |type|
      cut, size = type.values_at(:cut, :size)
      font = %(--#{type[:role]}-font: "#{cut.family}", monospace; --#{type[:role]}-fs: #{size}px; --#{type[:role]}-lh: #{size + cut.leading}px;)
      # A Markdown {size:…} marker scales the body's font (MarkdownHelper).
      font += " font-weight: #{cut.weight}; --md-grid: #{cut.grid}px; --md-leading: #{cut.leading}px;" if type[:role] == "body"
      ".card.#{type[:class]} { #{font} }"
    end

    [ *faces, *rules ].join("\n")
  end

  # Each font this look sets: the role it sets (the card's body or
  # header), the cut and size nearest its target, and the class naming
  # them.
  def types
    FONTS.filter_map do |setting|
      font = NewspaperFont.find(@fonts[setting]) or next

      role   = setting == "header_font" ? "header" : "body"
      target = role == "header" ? HEADER_TARGET : TARGETS.fetch(@choices["scale"])
      cut, size = font.nearest(target)

      { role:, cut:, size:, class: "look--#{role}-#{cut.key}-#{size}" }
    end
  end

  private

    def type_classes
      types.map { it[:class] }
    end
end
