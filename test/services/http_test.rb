require "test_helper"

class HttpTest < ActiveSupport::TestCase
  # Answers Net::HTTP.start with a canned response per URL, standing in
  # for the network.
  def with_responses(responses)
    singleton = Net::HTTP.singleton_class
    original  = singleton.instance_method(:start)
    singleton.define_method(:start) do |host, port, **, &block|
      http = Object.new
      http.define_singleton_method(:request) { |request| responses.fetch(request.uri.to_s).call }
      block.call(http)
    end

    yield
  ensure
    singleton.define_method(:start, original)
  end

  def ok(body)
    -> { Net::HTTPOK.new("1.1", "200", "OK").tap { it.instance_variable_set(:@body, body); it.instance_variable_set(:@read, true) } }
  end

  def redirect(location)
    -> { Net::HTTPMovedPermanently.new("1.1", "301", "Moved").tap { it["location"] = location } }
  end

  test "follows redirects, including relative ones" do
    responses = {
      "http://old.example.com/feed" => redirect("https://new.example.com/feed"),
      "https://new.example.com/feed" => redirect("/rss.xml"),
      "https://new.example.com/rss.xml" => ok("<rss/>")
    }

    with_responses(responses) do
      assert_equal "<rss/>", Http.get("http://old.example.com/feed")
    end
  end

  test "gives up on a redirect loop" do
    responses = { "https://loop.example.com/" => redirect("https://loop.example.com/") }

    with_responses(responses) do
      error = assert_raises(Http::Error) { Http.get("https://loop.example.com/") }
      assert_match(/too many redirects/, error.message)
    end
  end
end
