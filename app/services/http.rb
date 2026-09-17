# app/services/http.rb
require "net/http"

module Http
  class Error < StandardError; end

  TIMEOUT = 10
  USER_AGENT = "eink-dashboard/1.0"
  MAX_REDIRECTS = 5

  # Follows redirects: feeds and calendars move (http to https, a new
  # host, FeedBurner) and keep answering at the old address with a 301.
  def self.get(url, headers: {}, redirects: MAX_REDIRECTS)
    uri = URI.parse(url)
    raise Error, "unsupported scheme" unless uri.is_a?(URI::HTTP)

    response = Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: TIMEOUT,
      read_timeout: TIMEOUT
    ) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      headers.each { |k, v| request[k] = v }
      http.request(request)
    end

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      location = response["location"]
      raise Error, "#{response.code} from #{uri.host} with nowhere to go" if location.blank?
      raise Error, "too many redirects from #{uri.host}" if redirects <= 0

      get(URI.join(uri, location).to_s, headers: headers, redirects: redirects - 1)
    else
      raise Error, "#{response.code} from #{uri.host}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "timed out fetching #{uri&.host}"
  rescue URI::InvalidURIError, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => e
    raise Error, e.message
  end

  def self.get_json(url, headers: {})
    JSON.parse(get(url, headers: headers))
  end
end
