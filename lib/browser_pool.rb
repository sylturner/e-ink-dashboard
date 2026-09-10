require "ferrum"

# Held outside app/ so the development reloader never discards it while
# the underlying Chrome process is still alive.
module BrowserPool
  LOCK = Mutex.new

  # How long to hold the capture for slow fonts or remote images before
  # screenshotting whatever has arrived. Kept under protocol_timeout so a
  # slow image never surfaces as a Ferrum error, which would tear down Chrome.
  ASSET_WAIT_MS = 7_000

  # Resolves once fonts are ready and every <img> has loaded and decoded
  # (or failed), or after ASSET_WAIT_MS, whichever comes first. decode()
  # waits for an in-flight load, so images still downloading are covered.
  WAIT_FOR_ASSETS_JS = <<~JS.freeze
    const done = arguments[0];
    const images = Array.from(document.images, (img) => img.decode().catch(() => {}));
    Promise.race([
      Promise.all([document.fonts.ready, ...images]),
      new Promise((resolve) => setTimeout(resolve, #{ASSET_WAIT_MS}))
    ]).then(() => done(true));
  JS

  class << self
    # Pass html: for normal captures. Local assets are inlined, but content
    # like news images still loads from remote URLs, so the capture waits
    # for those before taking the screenshot.
    # url: exists only for debugging against a live page.
    def capture(html: nil, url: nil, width: 800, height: 480)
      raise ArgumentError, "pass html: or url:" if html.nil? && url.nil?

      LOCK.synchronize do
        with_retry do
          page = browser.create_page
          begin
            page.resize(width: width, height: height)
            html ? (page.content = html) : page.go_to(url)
            page.evaluate_async(WAIT_FOR_ASSETS_JS, (ASSET_WAIT_MS / 1000) + 2)
            # Must be the capture page's network; browser.network is the
            # default tab, which never sees this page's requests.
            page.network.wait_for_idle(timeout: 2)
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
        window_size: [ 800, 480 ],
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
