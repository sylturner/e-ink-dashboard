require "ferrum"

# Held outside app/ so the development reloader never discards it while
# the underlying Chrome process is still alive.
module BrowserPool
  LOCK = Mutex.new

  class << self
    # Pass html: for normal captures. Chrome renders it directly and makes
    # no network requests, so nothing can deadlock against Rails.
    # url: exists only for debugging against a live page.
    def capture(html: nil, url: nil, width: 800, height: 480)
      raise ArgumentError, "pass html: or url:" if html.nil? && url.nil?

      LOCK.synchronize do
        with_retry do
          page = browser.create_page
          begin
            page.resize(width: width, height: height)
            html ? (page.content = html) : page.go_to(url)
            page.evaluate_async(<<~JS, 5)
              document.fonts.ready.then(() => arguments[0](true))
            JS
            page.screenshot(encoding: :binary, format: :png)
          ensure
            begin
              page.close
            rescue StandardError
              nil
            end
          end
        end
      end
    end

    def shutdown
      LOCK.synchronize { teardown }
    end

    private

    def with_retry
      attempts = 0
      begin
        attempts += 1
        yield
      rescue Ferrum::Error, IOError, Errno::EPIPE, Errno::ECONNREFUSED => e
        Rails.logger.warn("[BrowserPool] #{e.class}: #{e.message}")
        teardown
        retry if attempts < 2
        raise
      end
    end

    def browser
      @browser ||= Ferrum::Browser.new(
        browser_path: ENV["CHROME_PATH"],
        window_size: [800, 480],
        timeout: 10,
        process_timeout: 20,
        protocol_timeout: 10,
        pending_connection_errors: false,
        browser_options: {
          "no-sandbox" => nil,
          "disable-dev-shm-usage" => nil,
          "disable-gpu" => nil,
          "hide-scrollbars" => nil,
          "force-device-scale-factor" => "1",
          "disable-background-timer-throttling" => nil,
          "disable-backgrounding-occluded-windows" => nil,
          "disable-renderer-backgrounding" => nil
        }
      )
    end

    def teardown
      @browser&.quit
    rescue StandardError
      nil
    ensure
      @browser = nil
    end
  end
end

at_exit { BrowserPool.shutdown }

