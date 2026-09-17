require "test_helper"

class Api::LogsControllerTest < ActionDispatch::IntegrationTest
  def capturing_log
    output = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(output))
    yield
    output.string
  ensure
    Rails.logger = original
  end

  test "a panel's logs go to the Rails log, tagged with its name" do
    device = devices(:one)

    log = capturing_log do
      post api_log_url, as: :json,
           params: { logs: [ { message: "Wi-Fi retry", level: "error" } ] },
           headers: { "ID" => "aa:bb:cc:dd:ee:ff", "Access-Token" => device.token }
    end

    assert_response :no_content
    assert_match(/\[TRMNL\] \[#{device.name}\] .*Wi-Fi retry/, log)
  end

  test "a panel that hasn't set up is still heard, by its MAC" do
    log = capturing_log do
      post api_log_url, as: :json, params: { logs: [ { message: "No key yet" } ] },
           headers: { "ID" => "AA:BB:CC:DD:EE:FF" }
    end

    assert_response :no_content
    assert_match(/\[aa:bb:cc:dd:ee:ff\] .*No key yet/, log)
  end
end
