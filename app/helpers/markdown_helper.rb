# Markdown drawn on a 1-bit panel: a note (renders/items/_note) or a text
# tile's formatted layout (renders/items/_text).
module MarkdownHelper
  # What Markdown can draw. A link keeps only its text, since a panel can't
  # follow it; raw HTML and everything else are dropped.
  MARKDOWN_TAGS = %w[p br h1 h2 h3 h4 h5 h6 strong em del ul ol li blockquote hr
                     code pre input table thead tbody tr th td img].freeze
  MARKDOWN_ATTRIBUTES = %w[type checked disabled src alt].freeze

  MARKDOWN_OPTIONS = {
    # Straight quotes: the panel's pixel fonts have no curly ones.
    parse: { smart: false },
    # A line break typed on a phone stays a line break. Raw HTML is left out.
    render: { hardbreaks: true, unsafe: false },
    # No autolinks, no emoji shortcodes (a color glyph thresholds into a
    # blob) and no heading anchors.
    extension: { strikethrough: true, tasklist: true, table: true, tagfilter: true,
                 autolink: false, shortcodes: false, header_ids: nil }
  }.freeze

  # Type markers, which Markdown has no syntax for: {font:jersey}…{/font}
  # sets text in a NewspaperFont, {size:large}…{/size} scales it by whole
  # multiples of its font's pixel grid (.md-size--* in render.css). A marker
  # applies within one paragraph, heading or list item; one that spans
  # more, names no font or size, or isn't closed, is drawn as typed.
  SIZES = %w[small medium large huge].freeze
  FONT_MARKER = /\{font:([a-z0-9_]+)\}((?:(?!\{\/?font[:}]).)*?)\{\/font\}/m
  SIZE_MARKER = /\{size:([a-z]+)\}((?:(?!\{\/?size[:}]).)*?)\{\/size\}/m
  BLOCK_TAG = %r{</?(?:p|h[1-6]|ul|ol|li|blockquote|pre|table|thead|tbody|tr|th|td|hr)\b}

  # The most an uploaded image is drawn at: a whole panel.
  IMAGE_LIMIT = [ 800, 800 ].freeze

  def markdown(text)
    # Also spares commonmarker the frozen US-ASCII "" of nil.to_s, which it refuses.
    return "" if text.blank?

    html = Commonmarker.to_html(text, options: MARKDOWN_OPTIONS, plugins: { syntax_highlighter: nil })
    panel_type(panel_images(sanitize(html, tags: MARKDOWN_TAGS, attributes: MARKDOWN_ATTRIBUTES)))
  end

  private

    # Turns type markers into spans, innermost first, and adds the faces
    # and classes of the fonts they name.
    def panel_type(html)
      return html unless html.include?("{font:") || html.include?("{size:")

      html = String.new(html)
      loop do
        before = html.dup
        html.gsub!(FONT_MARKER) { type_span($~, NewspaperFont.find($1)&.markdown_class) }
        html.gsub!(SIZE_MARKER) { type_span($~, ("md-size--#{$1}" if SIZES.include?($1))) }
        break if html == before
      end

      fonts = html.scan(/class="md-font--([a-z0-9_]+)"/).flatten.uniq.map { NewspaperFont.find(it) }
      return html.html_safe if fonts.empty?

      css = fonts.map { it.nearest(16).first }.uniq(&:key).reject(&:shared?).map(&:face) + fonts.map(&:markdown_css)
      safe_join([ html.html_safe, tag.style(css.join("\n").html_safe) ])
    end

    # A marker's span, or the marker as typed when it names nothing or
    # spans blocks.
    def type_span(match, css_class)
      return match[0] if css_class.nil? || match[2].match?(BLOCK_TAG)

      %(<span class="#{css_class}">#{match[2]}</span>)
    end

    # Points each image at something the panel's capture can load. A frame
    # is rendered with no request to fetch through, so an uploaded image is
    # inlined; one on the web is loaded from there (the capture waits for
    # it). Anything else can't be drawn and is dropped.
    def panel_images(html)
      return html unless html.include?("<img")

      fragment = Nokogiri::HTML5.fragment(html)
      fragment.css("img").each do |image|
        source = panel_image_source(image["src"].to_s)
        source ? image["src"] = source : image.remove
      end
      # Sanitized above; only the sources have changed.
      fragment.to_html.html_safe
    end

    def panel_image_source(src)
      if src.match?(MarkdownImages::SRC)
        blob = MarkdownImages.blob_for(src)
        inline_image(blob) if blob&.image?
      elsif src.match?(%r{\Ahttps?://}i)
        src
      end
    end

    # A panel-sized gray copy of an uploaded image, as a data: URI. The
    # panel's own dithering takes it to 1-bit. An image that can't be read
    # is left out rather than stopping the whole frame.
    def inline_image(blob)
      variant = blob.variant(resize_to_limit: IMAGE_LIMIT, colourspace: "b-w", format: :png).processed
      "data:image/png;base64,#{Base64.strict_encode64(variant.download)}"
    rescue StandardError => error
      Rails.logger.warn("Couldn't draw image #{blob.id}: #{error.class}: #{error.message}")
      nil
    end
end
