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

  test "to_png draws 1 bits white and 0 bits black, at the bitmap's size" do
    # 10 wide, so the last byte's six padding bits must be dropped.
    bitmap = Bitmap.new(width: 10, height: 1, rows: [ [ 0b1010_0000, 0b0100_0000 ].pack("C*") ])

    image = Vips::Image.new_from_buffer(bitmap.to_png, "")

    assert_equal [ 10, 1 ], [ image.width, image.height ]
    assert_equal [ 255, 0, 255, 0, 0, 0, 0, 0, 0, 255 ], image.to_a.flatten
  end

  test "to_png is 1-bit, so a panel's download stays small" do
    bytes = Bitmap.from_png(png).to_png

    # IHDR's bit depth: after the signature, chunk length, type, width and height.
    assert_equal 1, bytes.getbyte(24)
  end

  test "to_format sends a PNG for png and a BMP otherwise" do
    bitmap = Bitmap.from_png(png)

    assert_equal bitmap.to_png, bitmap.to_format("png")
    assert_equal bitmap.to_bmp, bitmap.to_format("bmp")
  end

  test "to_bmp emits a valid 1-bit BMP header" do
    bytes = Bitmap.from_png(png).to_bmp

    assert_equal "BM", bytes[0, 2]
    assert_equal 62, bytes[10, 4].unpack1("V")      # pixel data offset
    assert_equal 1, bytes[28, 2].unpack1("v")       # bit depth
  end

  # TRMNL's firmware checks exactly these and rejects anything else.
  test "an 800x480 BMP has the header TRMNL's firmware accepts" do
    bytes = Bitmap.new(width: 800, height: 480, rows: Array.new(480) { "\xFF".b * 100 }).to_bmp

    assert_equal [ 800, 480 ], bytes[18, 8].unpack("V2")
    assert_equal 1, bytes[28, 2].unpack1("v")             # bits per pixel
    assert_equal 48_000, bytes[34, 4].unpack1("V")        # pixel data size
    assert_equal 2, bytes[46, 4].unpack1("V")             # palette entries
    assert_equal [ 0, 0, 0, 0, 255, 255, 255, 0 ], bytes[54, 8].bytes # black, then white
  end
end
