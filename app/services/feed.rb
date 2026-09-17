# app/services/feed.rb
#
# Reads any syndication feed into one shape: RSS 0.9x/1.0/2.0, Atom,
# JSON Feed, and podcast (iTunes) RSS. Feedjira picks the parser and does
# titles, links and dates, which it handles well across formats. Images
# it maps inconsistently (an audio <enclosure> comes back as an entry's
# "image"), so they're read here from the XML directly, recognized by
# local name and attributes so a feed's choice of namespace prefix
# doesn't matter.
class Feed
  ACCEPT = "application/rss+xml, application/atom+xml, application/feed+json, " \
           "application/xml;q=0.9, text/xml;q=0.9, application/json;q=0.8, */*;q=0.7"

  DISCOVERABLE_TYPES = %w[
    application/rss+xml application/atom+xml application/feed+json
    application/json application/rdf+xml application/xml text/xml
  ].freeze

  BOM = "\xEF\xBB\xBF".b

  NON_IMAGE_EXTENSION = /\.(mp3|m4a|m4b|aac|ogg|oga|opus|wav|flac|mp4|m4v|mov|webm|mkv|avi|pdf|torrent)(\?|#|\z)/i
  IMAGE_EXTENSION     = /\.(jpe?g|png|gif|webp|avif|bmp|svg)(\?|#|\z)/i

  # Beacons and chrome that show up as <img> in feed HTML but aren't the
  # post's picture.
  NOT_A_PICTURE = %r{
    feeds\.feedburner\.com/~ | feedblitz\.com/~/ | feedsportal\.com |
    pixel\.wp\.com | stats\.wordpress\.com | s\.w\.org/images/core/emoji |
    gravatar\.com/avatar | doubleclick\.net | /tracking/ | [/.]pixel\.(gif|png)
  }xi

  TITLE_LENGTH   = 140
  SUMMARY_LENGTH = 500

  # An item's every element, kept for headline templates (see #fields).
  # Capped, because a payload holds them for every item it keeps.
  FIELD_LENGTH = 500
  FIELD_LIMIT  = 60

  # A page URL is fine too: if the response is HTML, the feed it
  # advertises with <link rel="alternate"> is fetched instead.
  def self.fetch(url)
    body = Http.get(url, headers: { "Accept" => ACCEPT })
    return new(body, url: url) if parser_for(body)

    discovered = discover(body, url: url)
    raise Http::Error, "no feed found at #{url.truncate(80)}" unless discovered

    new(Http.get(discovered, headers: { "Accept" => ACCEPT }), url: discovered)
  end

  def self.parser_for(body)
    body = strip_bom(body)
    return Feedjira::Parser::JSONFeed if body.lstrip.start_with?("{")

    Feedjira.parser_for_xml(body)
  end

  def self.discover(html, url:)
    Nokogiri::HTML(html).css("link[href]").each do |link|
      next unless link["rel"].to_s.downcase.split.include?("alternate")
      next unless DISCOVERABLE_TYPES.include?(link["type"].to_s.downcase.split(";").first.to_s.strip)

      href = absolute(link["href"], url)
      return href if href
    end
    nil
  end

  def self.strip_bom(body)
    body.b.delete_prefix(BOM)
  end

  # Relative and protocol-relative references are common in feed HTML.
  # Anything that doesn't come out as http(s) (data:, javascript:) is
  # dropped: a panel can't follow it and a beacon often hides in it. So is
  # a script's unfilled placeholder, which would otherwise resolve to a
  # page on the feed's site.
  def self.absolute(ref, base)
    ref = ref.to_s.strip
    return if ref.empty? || ref.match?(/\A(undefined|null|none|#.*)\z/i)

    uri = begin
      URI.join(base, ref)
    rescue URI::InvalidURIError
      # Unescaped spaces and non-ASCII turn up in feed URLs.
      URI.join(base, URI::RFC2396_PARSER.escape(ref))
    end
    uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::Error
    nil
  end

  attr_reader :url

  def initialize(body, url:)
    @body   = self.class.strip_bom(body)
    @url    = url
    @parser = self.class.parser_for(@body)
    raise Http::Error, "not a feed (RSS, Atom or JSON Feed)" unless @parser

    @feed = json? ? parse_json : @parser.parse(@body)
    raise Http::Error, "could not parse feed" unless @feed
  rescue JSON::ParserError, KeyError, TypeError => e
    raise Http::Error, "could not parse feed: #{e.message.truncate(120)}"
  end

  def title
    @title ||= clean(@feed.title).presence || URI.parse(url).host
  rescue URI::Error
    nil
  end

  # The feed's own picture: a podcast's artwork, a publication's logo.
  def image
    @image ||= artwork || (json? ? json_feed_image : xml_feed_image)
  end

  # Newest first when every entry is dated. Most feeds already are, but
  # some podcasts and archives list oldest first, and a panel only shows
  # the top few. Images are looked up only for the items kept: a long
  # podcast feed has thousands of episodes.
  def items(limit: nil)
    entries = @feed.entries.each_with_index.map { |entry, index| [ entry, entry_nodes[index] ] }
    entries = entries.sort_by { |entry, _| entry.published }.reverse if entries.all? { |entry, _| entry.published }

    entries.lazy.filter_map { |entry, node| item(entry, node) }.first(limit || entries.size)
  end

  private

    def json?
      @parser == Feedjira::Parser::JSONFeed
    end

    # Feedjira's JSON Feed reader fetches keys the spec makes optional
    # (an item's url, a feed's title) and raises without them.
    def parse_json
      json = JSON.parse(@body.dup.force_encoding(Encoding::UTF_8))
      raise Http::Error, "not a feed (RSS, Atom or JSON Feed)" unless json.is_a?(Hash)

      json["title"] ||= nil
      json["items"] = Array(json["items"]).grep(Hash).map do |item|
        item.merge("url" => item["url"] || item["external_url"],
                   "id"  => item["id"] || item["url"] || item["external_url"])
      end
      @parser.new(json)
    end

    def item(entry, node)
      link     = self.class.absolute(entry.url, url)
      fields   = fields(entry, node)
      text     = clean(entry.summary.presence || entry.content)
      title    = without_outlet(clean(entry.title), fields["source"]).presence
      headline = title || text.truncate(TITLE_LENGTH, separator: " ").presence
      return unless headline || link

      text = "" if title && echoes?(text, title)

      {
        "title"        => headline.to_s,
        "url"          => link,
        "published_at" => entry.published&.utc&.iso8601,
        "image"        => entry_image(entry, node, link || url) || artwork,
        "source"       => self.title,
        "summary"      => text.truncate(SUMMARY_LENGTH, separator: " ").presence,
        "author"       => author(entry, fields),
        "fields"       => fields
      }
    end

    # Aggregators (Google News) end a headline with the outlet their
    # <source> names ("Fed hikes rates - Reuters"). A byline says that.
    def without_outlet(title, outlet)
      return title if outlet.blank?

      title.delete_suffix(" - #{outlet}").delete_suffix(" | #{outlet}")
    end

    # Aggregators (Google News) describe an item with nothing but its own
    # headline and outlet, which isn't a summary worth drawing under it.
    # Punctuation differs between the two ("Title - Reuters", "Title
    # Reuters"), so only letters and digits are compared.
    def echoes?(text, title)
      letters = ->(s) { s.downcase.gsub(/[^[:alnum:]]/, "") }
      letters.(text).start_with?(letters.(title))
    end

    # Feedjira reads <author>, <dc:creator> and Atom's <author><name>. JSON
    # Feed 1.1 moved to an authors list it doesn't read, and a podcast
    # names its host with <itunes:author>.
    def author(entry, fields)
      clean(entry.author).presence ||
        fields.values_at("authors/name", "itunes:author").compact.first
    end

    # --- Fields ------------------------------------------------------------

    # Every element and attribute of an item by its path, so a headline
    # template can draw what a feed carries beyond the fields above:
    # {dc:creator}, {category}, {enclosure@length},
    # {media:group/media:title}. Paths use the feed's own prefixes, and a
    # repeated element's values join into one.
    def fields(entry, node)
      pairs = if node then xml_fields(node) elsif json? then json_fields(entry.json) else [] end

      values = pairs.each_with_object({}) do |(path, value), found|
        value = clean(value).truncate(FIELD_LENGTH, separator: " ")
        (found[path] ||= []) << value if value.present? && !found[path]&.include?(value)
      end
      values.first(FIELD_LIMIT).to_h { |path, list| [ path, list.join(", ") ] }
    end

    def xml_fields(node, parent = nil)
      node.element_children.flat_map do |child|
        path       = [ parent, qualified_name(child) ].compact.join("/")
        attributes = child.attribute_nodes.map { [ "#{path}@#{qualified_name(it)}", it.value ] }
        contents   = child.element_children.any? ? xml_fields(child, path) : [ [ path, child.text ] ]

        attributes + contents
      end
    end

    def qualified_name(node)
      prefix = node.namespace&.prefix
      prefix ? "#{prefix}:#{node.name}" : node.name
    end

    # A list is looked through rather than numbered, as a repeated XML
    # element is: {tags}, {authors/name}.
    def json_fields(value, parent = nil)
      case value
      when Hash  then value.flat_map { |key, inner| json_fields(inner, [ parent, key ].compact.join("/")) }
      when Array then value.flat_map { json_fields(it, parent) }
      when nil   then []
      else [ [ parent, value.to_s ] ]
      end
    end

    # Feed titles carry entities and stray markup often enough to matter,
    # and a stray tag renders as literal text on the panel. Parsing as HTML
    # decodes every named entity (&nbsp;, &mdash;), not just the few
    # CGI.unescapeHTML knows.
    def clean(text)
      return "" if text.blank?

      fragment = Nokogiri::HTML::DocumentFragment.parse(text.to_s)
      fragment.css("script, style").remove
      fragment.text.gsub(/[[:space:]]+/, " ").strip
    end

    # --- Images ------------------------------------------------------------

    def entry_image(entry, node, base)
      candidates =
        if node
          [ *media_images(node), *enclosure_images(node), *itunes_images(node), *plain_images(node) ]
        elsif json?
          [ entry.image, entry.banner_image ]
        else
          []
        end

      candidates.each do |ref|
        found = self.class.absolute(ref, base)
        return found if found
      end

      html_image(entry.content, base) || html_image(entry.summary, base) || linked_image(base)
    end

    # Some feeds have nothing to read but a picture, and link the item
    # straight to it (a moon-phase feed linking to today's moon.gif).
    def linked_image(link)
      link if link&.match?(IMAGE_EXTENSION)
    end

    def document
      @document ||= Nokogiri::XML(@body)
    end

    # Feedjira collects entries by element name in document order, so the
    # same query lines them up with their XML. If the counts disagree,
    # images come only from each entry's HTML rather than risk a mismatch.
    def entry_nodes
      @entry_nodes ||= begin
        nodes = json? ? [] : document.xpath("//*[name()='item' or name()='entry']").to_a
        nodes.size == @feed.entries.size ? nodes : []
      end
    end

    # <media:content> and <media:thumbnail>, also inside <media:group>.
    # Content comes first, being the full picture rather than a preview,
    # and the widest of several sizes wins.
    def media_images(node)
      contents = node.xpath(".//*[local-name()='content'][@url]").select do |el|
        medium = el["medium"].to_s.downcase
        type   = el["type"].to_s.downcase
        next medium == "image" if medium.present?
        next type.start_with?("image/") if type.present?

        !el["url"].match?(NON_IMAGE_EXTENSION)
      end
      thumbnails = node.xpath(".//*[local-name()='thumbnail'][@url]")

      [ contents, thumbnails ].flat_map do |els|
        els.sort_by { -it["width"].to_i }.map { it["url"] }
      end
    end

    # RSS <enclosure url type> and Atom <link rel="enclosure" href type>.
    def enclosure_images(node)
      rss  = node.xpath("./*[local-name()='enclosure'][@url]").map { [ it["url"], it["type"] ] }
      atom = node.xpath("./*[local-name()='link'][@rel='enclosure'][@href]").map { [ it["href"], it["type"] ] }

      (rss + atom).filter_map do |ref, type|
        ref if type.present? ? type.downcase.start_with?("image/") : ref.match?(IMAGE_EXTENSION)
      end
    end

    # <itunes:image href> (and any other prefix's image with an href).
    def itunes_images(node)
      node.xpath("./*[local-name()='image'][@href]").map { it["href"] }
    end

    # An <image> on an item isn't in the RSS 2.0 spec but plenty of feeds
    # use one, either as a bare URL or shaped like the channel's <image>.
    def plain_images(node)
      node.xpath("./*[local-name()='image'][not(@href)]").map do |el|
        el.at_xpath("./*[local-name()='url']")&.text || el.text
      end
    end

    def html_image(html, base)
      return if html.blank? || !html.include?("<")

      Nokogiri::HTML::DocumentFragment.parse(html).css("img").each do |img|
        next if tiny?(img)

        src = self.class.absolute(img["src"].presence || img["data-src"], base)
        return src if src && !src.match?(NOT_A_PICTURE)
      end
      nil
    end

    def tiny?(img)
      %w[width height].any? do |dimension|
        value = img[dimension].to_s[/\A\s*(\d+)/, 1]
        value && value.to_i < 16
      end
    end

    # A podcast's show art, which stands in for an episode's own as
    # podcast apps do. A site's logo doesn't: a row of the same logo
    # isn't a picture of each story.
    def artwork
      return @artwork if defined?(@artwork)

      @artwork = channel && self.class.absolute(channel.at_xpath("./*[local-name()='image'][@href]")&.[]("href"), url)
    end

    # RSS 2.0 nests everything in <channel>; RSS 1.0 puts <image> and the
    # items beside it, and Atom has no channel at all.
    def channel
      return if json?

      @channel ||= document.root&.then { it.at_xpath("./*[local-name()='channel']") || it }
    end

    # RSS <image> is capped at 144px; Atom's <logo> is meant to be bigger
    # than its <icon>.
    def xml_feed_image
      root = document.root
      return unless root

      refs = [
        channel.at_xpath("./*[local-name()='image']/*[local-name()='url']")&.text,
        root.at_xpath("./*[local-name()='image']/*[local-name()='url']")&.text,
        root.at_xpath("./*[local-name()='logo']")&.text,
        root.at_xpath("./*[local-name()='icon']")&.text
      ]
      refs.lazy.filter_map { self.class.absolute(it, url) }.first
    end

    def json_feed_image
      [ @feed.icon, @feed.favicon ].lazy.filter_map { self.class.absolute(it, url) }.first
    end
end
