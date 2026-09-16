module NewsHelper
  # One line of a headline template filled from a NewsFeed entry, or nil
  # when it has nothing to draw.
  def headline_line(line, entry, now)
    published = published_in_zone(entry, now)

    NewsTemplate.fill(line.tokens, entry, named: {
      "date" => published && panel_date(published),
      "age"  => published && panel_age(published, now)
    })
  end

  # A story's source and age, "NPR News · 2h", as a newspaper prints its
  # byline. It names the source as it was named here: a feed's own title
  # can be a mouthful ("site:reuters.com" - Google News).
  def news_byline(entry, now)
    published = published_in_zone(entry, now)

    [ entry["source_name"], published && panel_age(published, now) ].compact_blank.join(" · ").presence
  end

  # When an upcoming event happens, as a newspaper's events box prints
  # it: "Today · 1:00 PM", "Tomorrow · All day", "Today · Now" for one
  # already under way.
  def newspaper_event_when(event, now)
    date = [ event.starts_at.to_date, now.to_date ].max
    day  = case (date - now.to_date).to_i
    when 0 then t("renders.newspaper.today")
    when 1 then t("renders.newspaper.tomorrow")
    else l(date, format: :panel_weekday)
    end

    time = if event.all_day then t("renders.newspaper.all_day")
    elsif event.starts_at <= now then t("renders.newspaper.now")
    else panel_time(event.starts_at, :time)
    end

    t("renders.newspaper.event_when", day:, time:)
  end

  # A zine's masthead, cut out letter by letter: each in one of
  # NewspaperStyle::RANSOM_LETTERS' fonts and treatments, picked by the
  # letter and its place so the mix looks random but never changes.
  def ransom_letters(name)
    treatments = NewspaperStyle::RANSOM_LETTERS.values.first.map(&:last)

    safe_join(name.to_s.each_char.with_index.map do |char, index|
      next tag.span(" ", class: "ransom-space") if char.blank?

      pick = (char.ord + index) % treatments.size
      tag.span(char, class: [ "ransom", "ransom-#{pick}", "ransom--#{treatments[pick]}" ])
    end)
  end

  # A headline with its letters shifted in a pattern
  # (NewspaperStyle::LETTER_SHIFTS), counting on across words so a wave
  # keeps rolling. Each word stays whole, so the headline still wraps
  # between words. A pattern that inverts a letter inverts only the first.
  def shifted_letters(text, pattern)
    pattern = NewspaperStyle::LETTER_SHIFTS.fetch(name = pattern)
    index   = -1

    safe_join(text.to_s.split(/(\s+)/).map do |word|
      next word if word.blank?

      tag.span(class: "shift-word") do
        safe_join(word.each_char.map do |char|
          index += 1
          tag.span(char, class: [ "shift", "shift-#{name}-#{index % pattern[:shifts].size}",
                                  ("shift--inverted" if index.zero? && pattern[:invert_first]) ])
        end)
      end
    end)
  end

  # Little pictures drawn on a pixel grid, for a paper's decorations: a
  # patriot's flag stars, a wizarding paper's sparkles. Whole-pixel rects
  # keep them crisp on the 1-bit panel.
  PIXEL_ART = {
    star: [
      "....#....",
      "...###...",
      "#########",
      ".#######.",
      "..#####..",
      ".###.###.",
      ".#.....#."
    ],
    sparkle: [
      "....#....",
      "....#....",
      "...#.#...",
      "..#...#..",
      "##.....##",
      "..#...#..",
      "...#.#...",
      "....#....",
      "....#...."
    ]
  }.freeze

  def pixel_art(name)
    rows  = PIXEL_ART.fetch(name)
    rects = rows.each_with_index.flat_map do |row, y|
      row.enum_for(:scan, /#+/).map { tag.rect(x: $~.begin(0), y:, width: $~[0].size, height: 1) }
    end

    tag.svg(safe_join(rects), class: [ "pixel-art", "pixel-art--#{name}" ], width: rows.first.size, height: rows.size,
            viewBox: "0 0 #{rows.first.size} #{rows.size}", "shape-rendering": "crispEdges", "aria-hidden": true)
  end

  private

    # Dates and ages are drawn in the panel's zone, from the moment the
    # frame is rendered for.
    def published_in_zone(entry, now)
      NewsFeed.published_at(entry)&.in_time_zone(now.time_zone)
    end
end
