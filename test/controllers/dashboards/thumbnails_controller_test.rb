require "test_helper"

class Dashboards::ThumbnailsControllerTest < ActionDispatch::IntegrationTest
  PNG = "\x89PNG\r\n\x1a\n not really a png".b

  setup do
    @dashboard = dashboards(:one)
  end

  test "serves the captured render as a PNG" do
    stub_method(BrowserPool, :capture, returns: PNG) do
      get dashboard_thumbnail_url(@dashboard, format: :png)
    end

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal PNG, response.body
  end

  test "an unchanged dashboard is revalidated without a capture" do
    stub_method(BrowserPool, :capture, returns: PNG) do
      get dashboard_thumbnail_url(@dashboard, format: :png)
    end
    etag = response.headers["ETag"]

    stub_method(BrowserPool, :capture, raises: RuntimeError.new("should not capture")) do
      get dashboard_thumbnail_url(@dashboard, format: :png), headers: { "If-None-Match" => etag }
    end

    assert_response :not_modified
  end

  test "a changed dashboard gets a new ETag" do
    stub_method(BrowserPool, :capture, returns: PNG) do
      get dashboard_thumbnail_url(@dashboard, format: :png)
      etag = response.headers["ETag"]

      @dashboard.update!(theme: "night")
      get dashboard_thumbnail_url(@dashboard, format: :png), headers: { "If-None-Match" => etag }
    end

    assert_response :success
  end

  test "a failed capture answers 503 instead of raising" do
    stub_method(BrowserPool, :capture, raises: IOError.new("Chrome went away")) do
      get dashboard_thumbnail_url(@dashboard, format: :png)
    end

    assert_response :service_unavailable
  end
end
