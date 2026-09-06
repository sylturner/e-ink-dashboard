# Place-name lookup for weather sources. Open-Meteo's geocoding endpoint
# is in the same family as the forecast API: no key, no signup.
module Geocoding
  ENDPOINT = "https://geocoding-api.open-meteo.com/v1/search".freeze

  def self.search(query, count: 6)
    return [] if query.blank?

    url = "#{ENDPOINT}?#{{ name: query, count: count, format: 'json' }.to_query}"

    Array(Http.get_json(url)["results"]).map do |result|
      {
        "label" => [ result["name"], result["admin1"], result["country_code"] ]
                     .compact_blank.join(", "),
        "latitude"  => result["latitude"],
        "longitude" => result["longitude"],
        "time_zone" => result["timezone"]
      }
    end
  end
end
