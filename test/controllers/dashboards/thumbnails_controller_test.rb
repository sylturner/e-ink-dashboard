require "test_helper"
require "vips"

class Dashboards::ThumbnailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dashboard = dashboards(:one)
    @device = devices(:one) # 800x480 bmp, showing dashboard one; its fixture frame has no data
  end

  def bitmap(fill, width = 800, height = 480)
    Bitmap.new(width:, height:, rows: Array.new(height) { fill.b * ((width + 7) / 8) })
  end

  # The list never waits on headless Chrome: a thumbnail is only ever a
  # frame that was already rendered.
  def get_thumbnail(dashboard, **options)
    stub_method(BrowserPool, :capture, raises: RuntimeError.new("should not capture")) do
      get dashboard_thumbnail_url(dashboard, format: :png), **options
    end
  end

  test "serves the newest frame rendered from the dashboard, as it was sent" do
    @device.frames.create!(dashboard: @dashboard, data: bitmap("\x00").to_bmp, format: "bmp", rendered_at: 1.hour.ago)
    newest = @device.frames.create!(dashboard: @dashboard, data: bitmap("\xFF").to_bmp, format: "bmp")

    get_thumbnail @dashboard

    assert_response :success
    assert_equal "image/bmp", response.media_type
    assert_equal newest.data.b, response.body.b
  end

  test "a raw frame is drawn to a PNG" do
    device = devices(:two) # 800x480 raw
    device.frames.create!(dashboard: dashboards(:two), data: bitmap("\xFF").to_raw, format: "raw")

    get_thumbnail dashboards(:two)

    assert_response :success
    assert_equal "image/png", response.media_type
    image = Vips::Image.new_from_buffer(response.body, "")
    assert_equal [ 800, 480 ], [ image.width, image.height ]
  end

  test "a frame belongs to the dashboard it was rendered from, not the one its panel shows now" do
    frame = @device.frames.create!(dashboard: dashboards(:two), data: bitmap("\xFF").to_bmp, format: "bmp")

    get_thumbnail @dashboard
    assert_response :not_found

    get_thumbnail dashboards(:two)
    assert_response :success
    assert_equal frame.data.b, response.body.b
  end

  test "a dashboard with no frame yet has nothing to show" do
    get_thumbnail Dashboard.create!(name: "Fresh", grid_columns: 4, grid_rows: 3)

    assert_response :not_found
  end

  test "an unchanged frame is revalidated with a 304" do
    @device.frames.create!(dashboard: @dashboard, data: bitmap("\xFF").to_bmp, format: "bmp")

    get_thumbnail @dashboard
    get_thumbnail @dashboard, headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
  end
end
