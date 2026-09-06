# app/services/http.rb
require "net/http"

module Http
  class Error < StandardError; end

  TIMEOUT = 10
  USER_AGENT = "eink-dashboard/1.0"

  def self.get(url, headers: {})
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

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "#{response.code} from #{uri.host}"
    end

    response.body
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "timed out fetching #{uri&.host}"
  rescue SocketError => e
    raise Error, e.message
  end

  def self.get_json(url, headers: {})
    JSON.parse(get(url, headers: headers))
  end
end
