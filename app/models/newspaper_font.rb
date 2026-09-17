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
    new("pixel_operator", "Pixel Operator", [ cut("pixel_operator", "PixelOperator.woff2", 16) ]),
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

  # Choices for a Custom newspaper's font settings.
  def self.options
    REGISTRY.values.map { [ it.label, it.key ] }
  end
end
