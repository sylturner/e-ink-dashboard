require "test_helper"

class FrameTest < ActiveSupport::TestCase
  setup do
    @device = devices(:one)
  end

  test "a frame's filename follows its image, not its row" do
    first  = @device.frames.create!(data: "one".b, format: "bmp")
    again  = @device.frames.create!(data: "one".b, format: "bmp")
    other  = @device.frames.create!(data: "two".b, format: "bmp")

    assert_equal first.filename, again.filename
    assert_not_equal first.filename, other.filename
    assert_match(/\A\h{24}\.bmp\z/, first.filename)
    assert_operator first.filename.length, :<, 36, "TRMNL's firmware keeps it in a 36-byte buffer"
  end

  test "a frame is served as the format it was rendered in" do
    assert_equal "image/bmp", Frame.new(format: "bmp").content_type
    assert_equal "image/png", Frame.new(format: "png").content_type
  end
end
