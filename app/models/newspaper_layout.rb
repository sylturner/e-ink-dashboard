# The headline sizes a newspaper tile's front page steps down through, in
# px, largest first: render.css has an .hl-<px> class for each. The page's
# fitting script (renders/items/_newspaper) picks the largest that fits.
module NewspaperLayout
  NAME_SIZES    = [ 72, 64, 56, 48, 40, 32, 24 ].freeze
  LEAD_SIZES    = [ 40, 36, 32, 28, 24, 20 ].freeze
  BIG_SIZES     = [ 28, 26, 24, 22, 20, 18, 16 ].freeze
  FEATURE_SIZES = [ 22, 20, 18, 16, 15, 14 ].freeze
  BRIEF_SIZES   = [ 16, 15, 14 ].freeze

  ALL = (NAME_SIZES + LEAD_SIZES + BIG_SIZES + FEATURE_SIZES + BRIEF_SIZES).uniq.sort.freeze
end
