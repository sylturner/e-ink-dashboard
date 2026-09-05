require "base64"

# Inlines a stylesheet and its font references into a single string,
# so a captured page needs zero network requests.
class InlineAssets
  CSS_DIR  = Rails.root.join("app/assets/stylesheets")
  FONT_DIR = Rails.root.join("app/assets/fonts")

  MIME = {
    ".ttf"   => "font/ttf",
    ".otf"   => "font/otf",
    ".woff"  => "font/woff",
    ".woff2" => "font/woff2"
  }.freeze

  URL_REF = /url\(\s*['"]?([^'")]+)['"]?\s*\)/

  class << self
    def css(name)
      if Rails.env.development?
        build(name)
      else
        @cache ||= {}
        @cache[name] ||= build(name)
      end
    end

    private

    def build(name)
      File.read(CSS_DIR.join(name)).gsub(URL_REF) do |match|
        path = FONT_DIR.join(File.basename(Regexp.last_match(1)))
        File.exist?(path) ? "url(#{data_uri(path)})" : match
      end
    end

    def data_uri(path)
      mime = MIME.fetch(File.extname(path).downcase, "application/octet-stream")
      "data:#{mime};base64,#{Base64.strict_encode64(File.binread(path))}"
    end
  end
end
