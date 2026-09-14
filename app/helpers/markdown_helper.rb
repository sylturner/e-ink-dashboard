# A note's Markdown, drawn on a 1-bit panel (renders/items/_note).
module MarkdownHelper
  # What a note can draw. A link keeps only its text, since a panel can't
  # follow it; images, raw HTML and everything else are dropped.
  MARKDOWN_TAGS = %w[p br h1 h2 h3 h4 h5 h6 strong em del ul ol li blockquote hr
                     code pre input table thead tbody tr th td].freeze
  MARKDOWN_ATTRIBUTES = %w[type checked disabled].freeze

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

  def markdown(text)
    # Also spares commonmarker the frozen US-ASCII "" of nil.to_s, which it refuses.
    return "" if text.blank?

    html = Commonmarker.to_html(text, options: MARKDOWN_OPTIONS, plugins: { syntax_highlighter: nil })
    sanitize(html, tags: MARKDOWN_TAGS, attributes: MARKDOWN_ATTRIBUTES)
  end
end
