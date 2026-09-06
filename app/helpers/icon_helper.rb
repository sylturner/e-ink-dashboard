module IconHelper
  # scale must be a whole number. Fractional scaling reintroduces
  # half-pixel edges, which is the thing this system exists to avoid.
  def weather_icon(name, scale: 2)
    grid = Icons::WEATHER.fetch(name.to_s, Icons::WEATHER["cloudy"])
    size = 16 * scale

    rects = grid.each_with_index.flat_map do |row, y|
      run_lengths(row).map do |x, len|
        %(<rect x="#{x * scale}" y="#{y * scale}" ) +
          %(width="#{len * scale}" height="#{scale}"/>)
      end
    end

    <<~SVG.html_safe
      <svg class="icon" width="#{size}" height="#{size}"
           viewBox="0 0 #{size} #{size}"
           shape-rendering="crispEdges"
           xmlns="http://www.w3.org/2000/svg">
        <g fill="currentColor">#{rects.join}</g>
      </svg>
    SVG
  end

  private

  # Collapse each row into [start_x, length] runs so one <rect>
  # covers a horizontal span instead of one per pixel.
  def run_lengths(row)
    runs = []
    x = 0
    while x < row.length
      if row[x] == "#"
        len = 0
        len += 1 while row[x + len] == "#"
        runs << [ x, len ]
        x += len
      else
        x += 1
      end
    end
    runs
  end
end
