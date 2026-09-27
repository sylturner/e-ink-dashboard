# The pixel fonts a newspaper tile can set its type in. A font has one or
# more cuts: the same design drawn on different pixel grids (Jersey 15, 20
# and 25). A cut is only crisp at a whole multiple of its grid, so every
# size a newspaper uses is one of those multiples (#sizes).
#
# Files are in app/assets/fonts, their licenses (CC0 or OFL) in
# app/assets/fonts/licenses. The grids were measured from the outlines.
class NewspaperFont
  # `leading` is px added to a cut's line height, which is otherwise its
  # size: most of these fonts fill their em box. `shared` names the family
  # render.css already declares for the file, so a page doesn't embed it
  # twice.
  Cut = Data.define(:key, :file, :grid, :weight, :leading, :shared) do
    def family
      shared || "np-#{key}"
    end

    def shared?
      shared.present?
    end

    # The multiples of the grid within `range`, largest first.
    def sizes(range)
      (1..(range.max / grid)).map { grid * it }.select { range.cover?(it) }.reverse
    end

    # The fitting script's name for this cut at a size: an .hl-<step>
    # class (NewspaperStyle#css).
    def step(size)
      "#{key}-#{size}"
    end

    # Its @font-face for a panel's page, the file inlined so the capture
    # needs no requests.
    def face
      %(@font-face { font-family: "#{family}"; src: url(#{InlineAssets.font(file)}); font-weight: #{weight}; font-display: block; })
    end
  end

  attr_reader :key, :label, :cuts

  def initialize(key, label, cuts)
    @key, @label, @cuts = key, label, cuts
  end

  def self.cut(key, file, grid, weight: 400, leading: 0, shared: nil)
    Cut.new(key:, file:, grid:, weight:, leading:, shared:)
  end

  REGISTRY = [
    new("jacquard", "Jacquard (blackletter)", [ cut("jacquard12", "Jacquard12-Regular.woff2", 21), cut("jacquard24", "Jacquard24-Regular.woff2", 43) ]),
    new("jacquarda_bastarda", "Jacquarda Bastarda (calligraphic)", [ cut("jacquarda_bastarda", "JacquardaBastarda9-Regular.woff2", 13, leading: 2) ]),
    new("jersey", "Jersey", [ cut("jersey15", "Jersey15-Regular.woff2", 27, leading: 1), cut("jersey20", "Jersey20-Regular.woff2", 34), cut("jersey25", "Jersey25-Regular.woff2", 41) ]),
    new("home_video", "Home Video (capitals)", [ cut("home_video", "HomeVideo-Regular.woff2", 20, leading: 2) ]),
    new("press_start", "Press Start 2P", [ cut("press_start", "PressStart2P-Regular.ttf", 8, leading: 2, shared: "PressStart2P") ]),
    new("pixel_operator_bold", "Pixel Operator Bold", [ cut("pixel_operator_bold", "PixelOperator-Bold.woff2", 16, weight: 700, shared: "Pixel Operator Bold") ]),
    new("pixel_operator", "Pixel Operator", [ cut("pixel_operator", "PixelOperator.woff2", 16, shared: "Pixel Operator") ]),
    new("pixel_operator_mono_bold", "Pixel Operator Mono Bold", [ cut("pixel_operator_mono_bold", "PixelOperatorMono-Bold.woff2", 16, weight: 700) ]),
    new("pixel_operator_mono", "Pixel Operator Mono (typewriter)", [ cut("pixel_operator_mono", "PixelOperatorMono.woff2", 16) ]),
    new("bitrimus", "Bitrimus (narrow)", [ cut("bitrimus", "Bitrimus.woff2", 16, leading: -1) ]),
    new("ithaca", "Ithaca", [ cut("ithaca", "Ithaca.woff2", 16) ]),
    new("spleen", "Spleen (terminal)", [ cut("spleen", "spleen.otf", 16, shared: "Spleen") ]),
    new("pixantiqua", "PixAntiqua (serif)", [ cut("pixantiqua", "PixAntiqua.woff2", 12, leading: 2) ]),
    new("vaticanus", "Vaticanus (roman capitals)", [ cut("vaticanus", "Vaticanus.woff2", 8, leading: 2) ]),
    new("pixeloid_sans", "Pixeloid Sans", [ cut("pixeloid_sans", "PixeloidSans.woff2", 9, leading: 2) ]),
    new("pixeloid_sans_bold", "Pixeloid Sans Bold", [ cut("pixeloid_sans_bold", "PixeloidSans-Bold.woff2", 9, weight: 700, leading: 2) ]),
    new("silkscreen", "Silkscreen", [ cut("silkscreen", "Silkscreen-Regular.ttf", 8, leading: 2, shared: "Silkscreen") ]),
    new("tiny5", "Tiny5", [ cut("tiny5", "Tiny5-Regular.woff2", 8, leading: 1) ])
  ].index_by(&:key).freeze

  def self.find(key)
    REGISTRY[key.to_s]
  end

  # Choices for a font setting: a Custom newspaper's, a tile's look.
  def self.options
    REGISTRY.values.map { [ it.label, it.key ] }
  end

  # The size the admin's font picker previews each font at.
  PREVIEW_SIZE = 20

  # The admin's font_previews.css: every font's first cut, and a class
  # that sets a font's name in it (FontPickerHelper). Generated, so it
  # can't drift from REGISTRY: `bin/rails fonts:previews` writes it, and
  # test/models/newspaper_font_test.rb checks it's current. The admin has
  # none of render.css, so shared faces are declared here too.
  def self.preview_css
    rules = REGISTRY.values.flat_map do |font|
      cut, size = font.nearest(PREVIEW_SIZE)
      [ %(@font-face { font-family: "#{cut.family}"; src: url("#{cut.file}"); font-weight: #{cut.weight}; font-display: swap; }),
        %(.#{font.preview_class} { font-family: "#{cut.family}", monospace; font-size: #{size}px; font-weight: #{cut.weight}; line-height: 1.25; }) ]
    end

    <<~CSS
      /* Generated by NewspaperFont.preview_css (bin/rails fonts:previews).
         Don't edit by hand. The font picker's previews (FontPickerHelper),
         on admin pages only. */

      #{rules.join("\n")}
    CSS
  end

  # The Markdown marker {font:<key>}…{/font} (MarkdownHelper): a class
  # that sets text in this font on the panel, at its size nearest the
  # text's, or scaled by a {size:…} marker around or inside it (.md-size--*
  # in render.css scales --md-grid).
  def markdown_class
    "md-font--#{key}"
  end

  def markdown_css
    cut, size = nearest(16)
    scale = size / cut.grid
    type  = "#{cut.grid}px * var(--md-scale, #{scale})"

    ".#{markdown_class} { font-family: \"#{cut.family}\", monospace; font-weight: #{cut.weight}; " \
      "--md-grid: #{cut.grid}px; --md-leading: #{cut.leading}px; " \
      "font-size: calc(#{type}); line-height: calc(#{type} + #{cut.leading}px); }"
  end

  # The admin class that sets text in this font (font_previews.css).
  def preview_class
    "font-preview--#{key}"
  end

  # The cut and size nearest `target` px, the larger one on a tie (easier
  # to read across a room). A size is a whole multiple of its cut's grid.
  def nearest(target)
    cuts.flat_map { |cut| cut.sizes(1..(target * 3)).map { [ cut, it ] } }
        .min_by { |cut, size| [ (size - target).abs, -size ] } ||
      [ cuts.first, cuts.first.grid ]
  end
end
