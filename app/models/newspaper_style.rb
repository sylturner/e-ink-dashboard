# How a newspaper tile looks: the type of paper it is. Each is one of the
# newspaper component's layouts (Component), so the inspector picks it as
# a layout and keeps parts for each.
#
# A style sets a font (NewspaperFont) for each role on the page, how the
# stories are arranged, and the decorations render.css draws for
# .paper--<key>. Custom takes its fonts, arrangement and capitals from the
# tile's settings.
class NewspaperStyle
  # `chrome` is optional: the font a style draws its interface in, such as
  # a classic Mac's menu bar and window titles (render.css reads it as
  # --paper-chrome).
  ROLES = %i[masthead headline subhead text label chrome].freeze

  # A masthead of cut-out letters in mixed fonts, instead of one font.
  RANSOM = "ransom".freeze

  LAYOUTS = %w[broadsheet tabloid].freeze

  # The most upcoming events the events box lists, before the fitting
  # script drops any that don't fit.
  EVENT_LIMIT = 6

  # Classic desktops draw their pages in system fonts, with window titles
  # and a menu bar in the chrome font.
  DESKTOP_FONTS = { layout: "broadsheet", masthead: "pixel_operator_bold", headline: "pixel_operator_bold",
                    subhead: %w[pixel_operator_bold bitrimus], text: "pixel_operator", label: "pixeloid_sans",
                    chrome: "pixel_operator_bold" }.freeze

  PRESETS = {
    "broadsheet" => { layout: "broadsheet", masthead: "jacquard", headline: "jersey",
                      subhead: %w[pixel_operator_bold bitrimus], text: "pixantiqua", label: "pixeloid_sans" },
    "tabloid"    => { layout: "tabloid", masthead: "jersey", headline: "jersey", caps: true, kicker: true,
                      subhead: %w[pixel_operator_bold bitrimus], text: "pixel_operator", label: "pixeloid_sans_bold",
                      lead_max: 82 },
    "zine"       => { layout: "broadsheet", masthead: RANSOM, headline: "home_video", caps: true, letters: "jumble", strip: true,
                      subhead: %w[pixel_operator_mono_bold], text: "pixel_operator_mono", label: "silkscreen" },
    "patriot"    => { layout: "broadsheet", masthead: "jacquard", headline: "jersey", caps: true, kicker: true, flag: true,
                      subhead: %w[ithaca bitrimus], text: "pixantiqua", label: "vaticanus" },
    # Its name is stretched to twice its height and its lead headline to
    # twice its width (render.css), so both are set at half size: the name
    # in its own range, the lead down to small headline sizes.
    "hacker"     => { layout: "broadsheet", masthead: "press_start", headline: "press_start", kicker: true, letters: "glitch",
                      strip: "binary", subhead: %w[pixel_operator_mono_bold], text: "spleen", label: "press_start", lead_min: 16,
                      name: 16..64, temperature: 24 },
    "wizard"     => { layout: "broadsheet", masthead: "jacquarda_bastarda", headline: "jacquard", kicker: true, flourish: true,
                      letters: "wave", strip: true,
                      subhead: %w[vaticanus bitrimus], text: "pixantiqua", label: "vaticanus", name: 13..32, lead_min: 16 },
    # Their boxes are windows on a desktop, under a menu bar (render.css).
    "mac"        => DESKTOP_FONTS,
    "windows"    => DESKTOP_FONTS
  }.freeze

  KEYS = [ *PRESETS.keys, "custom" ].freeze

  # The px each slot's headline sizes are drawn from. Big and feature
  # headlines continue down into the subhead's sizes; briefs use only
  # those.
  NAME    = 20..64
  LEAD    = 27..60
  BIG     = 16..41
  FEATURE = 16..27
  BRIEF   = 12..20

  # How a style shifts the letters of its column headlines
  # (NewsHelper#shifted_letters): each [right, down] in whole pixels, which
  # keeps them on the pixel grid where a rotation wouldn't. A wave rolls
  # along; a jumble looks pasted up by hand; a glitch is a clean line with
  # the odd letter torn loose. Only a headline's first letter is ever
  # inverted, never one inside it.
  LETTER_SHIFTS = {
    "wave"   => { invert_first: false, shifts: [ 0, 1, 2, 3, 3, 2, 1, 0, -1, -2, -3, -3, -2, -1 ].map { [ 0, it ] } },
    "jumble" => { invert_first: true, shifts: [ [ 0, 0 ], [ 0, -2 ], [ 0, 1 ], [ 0, -1 ], [ 0, 3 ], [ 0, 0 ],
                                                [ 0, -3 ], [ 0, 2 ], [ 0, -1 ], [ 0, 1 ], [ 0, 0 ] ] },
    "glitch" => { invert_first: true, shifts: [ [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 3, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ],
                                                [ -2, 1 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, 0 ], [ 0, -2 ], [ 0, 0 ],
                                                [ 0, 0 ], [ 0, 0 ] ] }
  }.freeze

  # What a style's side strip spells: its motto, or its motto in binary.
  STRIPS = %w[motto binary].freeze

  # Two sizes of cut-out letters, each a cycle of a font at a size and a
  # treatment (render.css .ransom-<treatment>).
  RANSOM_LETTERS = {
    "ransom-lg" => [ [ "jacquard24", 43, "plain" ], [ "jersey25", 41, "inverted" ], [ "press_start", 40, "boxed" ],
                     [ "pixel_operator_bold", 32, "inverted" ], [ "home_video", 40, "plain" ] ],
    "ransom-sm" => [ [ "jacquard12", 21, "plain" ], [ "jersey15", 27, "inverted" ], [ "press_start", 24, "boxed" ],
                     [ "pixel_operator_bold", 16, "inverted" ], [ "home_video", 20, "plain" ] ]
  }.freeze

  attr_reader :key, :layout, :fonts

  def self.for(item)
    key = KEYS.include?(item.view) ? item.view : KEYS.first
    return new(key, PRESETS.fetch(key)) unless key == "custom"

    base = PRESETS.fetch("broadsheet")
    new(key, base.merge(
      layout:   item.setting("layout").presence_in(LAYOUTS) || base[:layout],
      caps:     item.setting("caps"),
      masthead: font_key(item.setting("masthead_font"), base[:masthead], ransom: true),
      headline: font_key(item.setting("headline_font"), base[:headline]),
      subhead:  [ font_key(item.setting("subhead_font"), base[:subhead].first) ],
      text:     font_key(item.setting("text_font"), base[:text]),
      label:    font_key(item.setting("label_font"), base[:label])
    ))
  end

  def self.font_key(value, fallback, ransom: false)
    return RANSOM if ransom && value == RANSOM

    NewspaperFont.find(value) ? value : fallback
  end

  # Choices for a Custom newspaper's masthead, which can be cut out too.
  def self.masthead_options
    [ *NewspaperFont.options, [ "Ransom note (mixed)", RANSOM ] ]
  end

  def initialize(key, config)
    @key    = key
    @config = config
    @layout = config[:layout]
    @fonts  = ROLES.index_with { |role| Array(config[role]).map { NewspaperFont.find(it) }.compact }
  end

  def caps?   = @config[:caps] ? true : false
  def kicker? = @config[:kicker] ? true : false
  def flag?   = @config[:flag] ? true : false
  def flourish? = @config[:flourish] ? true : false
  # What its side strip spells (STRIPS), or nil for none.
  def strip
    @config[:strip] == true ? "motto" : @config[:strip].presence_in(STRIPS)
  end

  # The letter shifts its column headlines take (LETTER_SHIFTS), or nil.
  def letters
    @config[:letters].presence_in(LETTER_SHIFTS.keys)
  end
  def ransom? = @config[:masthead] == RANSOM
  def chrome? = fonts.fetch(:chrome).any?

  # The steps (.hl-<step> classes) a slot's headline steps down through,
  # largest first.
  def ladder(slot)
    case slot
    when :name    then ransom? ? RANSOM_LETTERS.keys : sizes(:masthead, @config[:name] || NAME)
    when :lead    then sizes(:headline, LEAD.min..(@config[:lead_max] || LEAD.max)) +
                       sizes(:headline, (@config[:lead_min] || BIG.min)...LEAD.min)
    when :big     then sizes(:headline, BIG) + sizes(:subhead, BRIEF)
    when :feature then sizes(:headline, FEATURE) + sizes(:subhead, BRIEF)
    when :brief   then sizes(:subhead, BRIEF)
    else raise ArgumentError, "no #{slot} slot"
    end.uniq
  end

  # The page's own stylesheet: its fonts, as data: URIs so the capture
  # needs no requests, and a class for every size it can step through.
  # Scoped to `id`, so two newspapers on one dashboard keep their own.
  def css(id)
    steps = %i[lead big feature brief].flat_map { ladder(it) }
    steps += ladder(:name) unless ransom?

    rules = [
      *used_cuts.reject(&:shared?).map { font_face(it) },
      *steps.uniq.map { "#{step_class(it)} { #{font(*step_cut(it))} }" },
      "##{id} { #{font(*body(:text, 12))} }",
      "##{id} :is(.paper-small, .paper-dateline, .paper-byline, .paper-events-title, .paper-kicker, .tag) { #{font(*body(:label, 8))} }",
      "##{id} .paper-event-title { #{font(*step_cut(ladder(:brief).first))} }",
      "##{id} .paper-temp { #{font(*temperature)} }"
    ]
    rules << "##{id} { --paper-chrome: #{font_value(*body(:chrome, 12))}; }" if chrome?
    rules += ransom_rules if ransom?
    rules += letter_rules if letters
    rules.join("\n")
  end

  private

    # A role's sizes within a range, largest first, its font's cuts merged
    # (the finer cut first where two share a size). Several fonts in a
    # role follow one another, so a narrower font can come last. A font
    # with no size in range gives its smallest size above it.
    def sizes(role, range)
      fonts.fetch(role).flat_map do |font|
        steps = font.cuts.flat_map { |cut| cut.sizes(range).map { [ cut, it ] } }
                    .sort_by { |cut, size| [ -size, -cut.grid ] }
        steps = [ [ font.cuts.first, font.cuts.first.grid * (range.min / font.cuts.first.grid.to_f).ceil ] ] if steps.empty?
        steps.map { |cut, size| cut.step(size) }
      end
    end

    def all_cuts
      NewspaperFont::REGISTRY.values.flat_map(&:cuts).index_by(&:key)
    end

    def step_cut(step)
      key, size = step.to_s.rpartition("-").then { [ it.first, it.last.to_i ] }
      [ all_cuts.fetch(key), size ]
    end

    def step_class(step)
      ".hl-#{step}"
    end

    # A body role's first cut at its smallest multiple of at least `min`.
    def body(role, min)
      cut = fonts.fetch(role).first.cuts.first
      [ cut, cut.grid * (min / cut.grid.to_f).ceil ]
    end

    # The weather ear's temperature: the headline size nearest 34px, or
    # the style's own size for a wide face.
    def temperature
      target = @config[:temperature] || 34
      step   = sizes(:headline, 16..41).min_by { (step_cut(it).last - target).abs }
      step_cut(step)
    end

    def used_cuts
      cuts  = %i[lead big feature brief].flat_map { ladder(it) }.map { step_cut(it).first }
      cuts += ransom? ? RANSOM_LETTERS.values.flatten(1).map { all_cuts.fetch(it.first) } : ladder(:name).map { step_cut(it).first }
      cuts += [ body(:text, 12), body(:label, 8), temperature ].map(&:first)
      cuts << body(:chrome, 12).first if chrome?
      cuts.uniq(&:key)
    end

    def font(cut, size)
      "font: #{font_value(cut, size)};"
    end

    def font_value(cut, size)
      %(#{cut.weight} #{size}px/#{size + cut.leading}px "#{cut.family}", monospace)
    end

    def font_face(cut)
      %(@font-face { font-family: "#{cut.family}"; src: url(#{InlineAssets.font(cut.file)}); font-weight: #{cut.weight}; font-display: block; })
    end

    def letter_rules
      LETTER_SHIFTS.fetch(letters)[:shifts].map.with_index do |(right, down), index|
        ".shift-#{letters}-#{index} { transform: translate(#{right}px, #{down}px); }"
      end
    end

    def ransom_rules
      RANSOM_LETTERS.flat_map do |step, letters|
        letters.map.with_index do |(key, size, _), index|
          ".hl-#{step} .ransom-#{index} { #{font(all_cuts.fetch(key), size)} }"
        end
      end
    end
end
