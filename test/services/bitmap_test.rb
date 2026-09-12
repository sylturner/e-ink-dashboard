require "test_helper"
require "vips"

class BitmapTest < ActiveSupport::TestCase
  # A 16x2 PNG: left half white, right half black.
  def png(width: 16, height: 2)
    row = ([ 255 ] * (width / 2)) + ([ 0 ] * (width / 2))
    Vips::Image.new_from_array([ row ] * height).cast("uchar").write_to_buffer(".png")
  end

  test "from_png packs 1 = white, MSB first" do
    bmp = Bitmap.from_png(png)

    assert_equal 16, bmp.width
    assert_equal 2, bmp.height
    # left byte all white, right byte all black
    assert_equal [ 0xFF, 0x00 ], bmp.rows.first.bytes
  end

  test "from_png with dither breaks a flat gray into a dot pattern" do
    gray = Vips::Image.black(16, 16).linear(1, 128).cast("uchar").write_to_buffer(".png")

    thresholded = Bitmap.from_png(gray)
    dithered    = Bitmap.from_png(gray, dither: "floyd_steinberg")

    assert_equal [ 0xFF ], thresholded.rows.map(&:bytes).flatten.uniq
    assert_operator dithered.rows.join.unpack1("B*").count("0"), :>, 64
  end

  test "from_png flattens transparency onto white" do
    clear = Vips::Image.black(8, 1, bands: 4).cast("uchar").write_to_buffer(".png")

    assert_equal [ 0xFF ], Bitmap.from_png(clear).rows.first.bytes
  end

  test "to_bmp emits a valid 1-bit BMP header" do
    bytes = Bitmap.from_png(png).to_bmp

    assert_equal "BM", bytes[0, 2]
    assert_equal 62, bytes[10, 4].unpack1("V")      # pixel data offset
    assert_equal 1, bytes[28, 2].unpack1("v")       # bit depth
  end
end
