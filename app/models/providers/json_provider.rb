# Any JSON a URL answers with: Home Assistant's states, a transit API's
# departures, a price. The payload is the parsed reply under "data",
# which a data tile draws through its template (DataTemplate).
class JsonProvider < ApplicationRecord
  include Providable

  provides label:           "JSON",
           icon:            "cil-code",
           description:     "Values from any web API that answers in JSON, drawn through a template.",
           attributes:      %i[url headers],
           refresh_seconds: 900

  # The largest reply kept, since the payload is stored whole.
  MAX_BYTES = 512.kilobytes

  HEADER_LINE = /\A([!#$%&'*+\-.^_`|~0-9A-Za-z]+):\s*(.*)\z/

  validates :url, presence: true, format: { with: %r{\Ahttps?://\S+\z} }
  validate :headers_are_lines

  before_validation { self.url = url.to_s.strip }

  def detail
    url.to_s.truncate(50)
  end

  def fetch!
    body = Http.get(url, headers: { "Accept" => "application/json" }.merge(header_hash))
    raise Http::Error, "reply is larger than #{MAX_BYTES / 1.kilobyte} KB" if body.bytesize > MAX_BYTES

    { "data" => JSON.parse(body) }
  rescue JSON::ParserError
    raise Http::Error, "reply isn't JSON"
  end

  # The request headers, one "Name: value" a line.
  def header_hash
    header_lines.to_h { it.match(HEADER_LINE).captures }
  end

  private

    def header_lines
      headers.to_s.lines.map(&:strip).compact_blank
    end

    def headers_are_lines
      bad = header_lines.reject { it.match?(HEADER_LINE) }
      errors.add(:headers, :invalid_lines, lines: bad.map { it.truncate(30) }.to_sentence) if bad.any?
    end
end
