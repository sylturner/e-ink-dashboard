# A path into parsed JSON, as a template's token names it: keys and list
# indexes joined by dots, "attributes.temperature", "departures.0.time".
# A key that has dots of its own ("sensor.kitchen") is found whole before
# being split. A key with other punctuation, like a feed item's
# "dc:creator" or "enclosure@length", is just a key.
module DataPath
  INDEX = /\A-?\d+\z/

  def self.dig(data, path)
    path = path.to_s
    return data if path.empty?

    walk(data, path.split(".", -1))
  end

  # Every value a template can draw, as [path, value] pairs in the data's
  # order, for listing under a template's field. A list is shown by its
  # first entry, which the others are taken to be shaped like.
  def self.leaves(data, limit: 40)
    pairs = []
    collect(data, nil, pairs, limit)
    pairs
  end

  def self.walk(node, segments)
    return node if segments.empty?

    case node
    when Hash
      # Longest key first, so "sensor.kitchen.state" finds "sensor.kitchen".
      segments.size.downto(1) do |count|
        key = segments.first(count).join(".")
        return walk(node[key], segments.drop(count)) if node.key?(key)
      end
      nil
    when Array
      walk(node[segments.first.to_i], segments.drop(1)) if segments.first.match?(INDEX)
    end
  end

  def self.collect(node, path, pairs, limit)
    return if pairs.size >= limit

    case node
    when Hash
      node.each { |key, value| collect(value, [ path, key ].compact.join("."), pairs, limit) }
    when Array
      if node.first.is_a?(Hash) || node.first.is_a?(Array)
        collect(node.first, [ path, 0 ].compact.join("."), pairs, limit)
      else
        pairs << [ path.to_s, node ]
      end
    else
      pairs << [ path.to_s, node ]
    end
  end

  private_class_method :walk, :collect
end
