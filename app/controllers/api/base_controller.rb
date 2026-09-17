# The panels' API: TRMNL's BYOS protocol (https://docs.trmnl.com/go/diy/byos),
# spoken by TRMNL's own panels and by the sketch in esp32/. A panel names
# itself by MAC in the ID header and, once set up, sends its API key --
# its Device#token -- in Access-Token.
#
# Deliberately unauthenticated: this runs on a home LAN, so anything that
# can reach it is already trusted. Setup is idempotent by MAC, so the
# worst a stray caller does is create a Device row that shows a setup
# screen until someone claims it.
class Api::BaseController < ApplicationController
  skip_forgery_protection

  private

    def current_device
      return @current_device if defined?(@current_device)

      token = request.headers["Access-Token"].presence
      @current_device = token && Device.find_by(token: token)
    end

    def mac
      request.headers["ID"].to_s.downcase.strip
    end

    def header_int(name)
      value = request.headers[name]
      value.presence && value.to_i
    end

    def header_float(name)
      value = request.headers[name]
      value.presence && value.to_f
    end
end
