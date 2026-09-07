module IconHelper
  # Weather Iconic glyphs are 32x32 line art painted with currentColor,
  # so they invert with their card like the rest of the ink. `size` is
  # the rendered edge in px; the vector scales cleanly to any value.
  def weather_icon(name, size: 32)
    body = Icons::WEATHER.fetch(name.to_s, Icons::WEATHER["clouds"])

    # A hairline stroke keeps the thin linework from breaking up once the
    # frame is thresholded to 1-bit. Holding it near half a device pixel
    # at any size firms the glyph up without filling the small counters.
    stroke = (16.0 / size).round(3)

    <<~SVG.html_safe
      <svg class="icon" width="#{size}" height="#{size}"
           viewBox="0 0 #{Icons::VIEWBOX} #{Icons::VIEWBOX}"
           fill="currentColor" stroke="currentColor" stroke-width="#{stroke}"
           fill-rule="evenodd" clip-rule="evenodd"
           xmlns="http://www.w3.org/2000/svg">#{body}</svg>
    SVG
  end
end
