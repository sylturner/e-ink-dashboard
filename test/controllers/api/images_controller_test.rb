require "test_helper"

class Api::ImagesControllerTest < ActionDispatch::IntegrationTest
  def white
    Bitmap.new(width: 800, height: 480, rows: Array.new(480) { "\xFF".b * 100 })
  end

  test "a bmp frame is sent as it was rendered" do
    frame = devices(:one).frames.create!(data: white.to_bmp, format: "bmp")

    get api_image_url(frame, format: "bmp")

    assert_response :success
    assert_equal "image/bmp", response.media_type
    assert_equal frame.data.b, response.body.b
  end

  # TRMNL's firmware decodes a PNG only when the content type says so.
  test "a png frame is sent as a png" do
    frame = devices(:two).frames.create!(data: white.to_png, format: "png")

    get api_image_url(frame, format: "png")

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal frame.data.b, response.body.b
  end

  test "a frame that was never rendered, or is gone, isn't found" do
    get api_image_url(frames(:one), format: "bmp") # no data
    assert_response :not_found

    get api_image_url(id: 0, format: "bmp")
    assert_response :not_found
  end
end
