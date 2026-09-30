# The tokens of a data tile's lines: {path} draws a value from its JSON
# source's data (DataPath), and {path|filter} or {path|filter:argument}
# draws it formatted. Inside a list the tile repeats its lines for, a
# path starts at the entry; "$." starts it at the top of the data again.
#
# The filters that turn a time into panel text need a view, so
# DataTilesHelper applies those; the rest are here.
class DataTemplate
  FILTERS = %w[round upcase downcase time date age until].freeze
  TIME_FILTERS = %w[time date age until].freeze

  # Most entries a list draws, whatever a tile asks for.
  LIST_LIMIT = 50

  # Most values listed under a tile's options and on its source's page.
  PATH_LIMIT = 60

  Token = Data.define(:path, :filter, :argument)

  # "attributes.temperature|round:1" as its path, filter and argument.
  # An unknown filter is dropped, and the value drawn as it is.
  def self.token(name)
    path, filter = name.to_s.split("|", 2)
    filter, argument = filter.to_s.split(":", 2)

    Token.new(path:, filter: FILTERS.include?(filter) ? filter : nil, argument:)
  end

  def self.lookup(path, data, root: data)
    return DataPath.dig(root, path.delete_prefix("$").delete_prefix(".")) if path == "$" || path.start_with?("$.")

    DataPath.dig(data, path)
  end

  # The entries of the list at `path`, or the data itself once when there
  # is no path. A path that isn't a list draws nothing.
  def self.entries(data, path, limit:)
    return [ data ] if path.blank?

    list = lookup(path.to_s.strip.delete_prefix("{").delete_suffix("}"), data)
    list.is_a?(Array) ? list.first(limit.to_i.clamp(1, LIST_LIMIT)) : []
  end

  # A value as text: a whole float without its ".0", a list of plain
  # values joined, and nothing for a list or object of objects, which
  # has no one line to draw.
  def self.text(value)
    case value
    when Float then value.finite? && value == value.round ? value.to_i.to_s : value.to_s
    when Array then value.all? { plain?(it) } ? value.map { text(it) }.compact_blank.join(", ") : ""
    when Hash then ""
    else value.to_s
    end
  end

  def self.filter(value, token)
    case token.filter
    when "round" then round(value, token.argument)
    when "upcase" then text(value).upcase
    when "downcase" then text(value).downcase
    else text(value)
    end
  end

  # A time in the data: an ISO 8601 string, or seconds since 1970 (or
  # milliseconds, which some APIs send).
  def self.moment(value, zone)
    case value
    when Numeric
      seconds = value.abs >= 100_000_000_000 ? value / 1000.0 : value
      Time.at(seconds).in_time_zone(zone)
    when String
      zone.iso8601(value.strip) if value.present?
    end
  rescue ArgumentError, RangeError
    nil
  end

  def self.plain?(value)
    !value.is_a?(Hash) && !value.is_a?(Array)
  end

  def self.round(value, places)
    number = Float(value, exception: false)
    return text(value) if number.nil? || !number.finite?

    places = places.to_i.clamp(0, 6)
    places.zero? ? number.round.to_s : format("%.#{places}f", number)
  end

  private_class_method :plain?, :round
end
