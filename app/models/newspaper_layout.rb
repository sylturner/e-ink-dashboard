# The sizes a newspaper tile's front page steps down through, largest
# first. Each names a render.css .hl-<size> class: a pixel face at a whole
# multiple of its grid, so a step can change face as well as size ("16n"
# is Bitrimus, narrower than 16's Pixel Operator). The page's fitting
# script (renders/items/_newspaper) picks the largest that fits.
module NewspaperLayout
  NAME_SIZES    = %w[63 43 21].freeze
  LEAD_SIZES    = %w[54 41 34 27].freeze
  BIG_SIZES     = %w[41 34 27 16 16n].freeze
  FEATURE_SIZES = %w[27 16 16n].freeze
  BRIEF_SIZES   = %w[16 16n].freeze

  # The most upcoming events the events box lists, before the fitting
  # script drops any that don't fit.
  EVENT_LIMIT = 6

  # Every step, largest first, as a ladder may take them.
  ORDER = %w[63 54 43 41 34 27 21 16 16n].freeze
end
