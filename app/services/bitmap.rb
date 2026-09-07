# app/services/bitmap.rb
require "vips"

class Bitmap
  attr_reader :width, :height, :rows

  def initialize(width:, height:, rows:)
    @width  = width
    @height = height
    @rows   = rows
  end

  # rows are top-down, 1 bit per pixel, MSB first, 1 = white.
  #
  # The dashboard HTML is authored to land on the pixel grid, so at 1:1
  # the capture is already almost pure black and white — this just packs
  # it. Anti-aliased curves (the weather glyphs) fall to whichever side
  # of `threshold` they cover more of.
  def self.from_png(png_bytes, bit_depth: 1, threshold: 128)
    raise ArgumentError, "only 1-bit is implemented" unless bit_depth == 1

    image  = Vips::Image.new_from_buffer(png_bytes, "").colourspace("b-w").extract_band(0)
    width  = image.width
    height = image.height

    # `>= threshold` yields a uchar mask: 255 where light (white), else 0.
    pixels = (image >= threshold).write_to_memory
    row_bytes = (width + 7) / 8

    rows = Array.new(height) do |y|
      buffer = Array.new(row_bytes, 0)
      pixels.byteslice(y * width, width).each_byte.with_index do |value, x|
        buffer[x / 8] |= (0x80 >> (x % 8)) unless value.zero?
      end
      buffer.pack("C*")
    end

    new(width: width, height: height, rows: rows)
  end

  def to_raw
    rows.join.b
  end

  def to_bmp
    row_bytes = rows.first.bytesize
    offset    = 62
    size      = offset + row_bytes * height

    file = [ "BM", size, 0, 0, offset ].pack("a2VvvV")
    dib  = [ 40, width, height, 1, 1, 0,
            row_bytes * height, 2835, 2835, 2, 2 ].pack("Vl<l<vvVVl<l<VV")
    palette = [ 0, 0, 0, 0, 255, 255, 255, 0 ].pack("C8")

    (file + dib + palette + rows.reverse.join).b
  end

  def to_format(format)
    format.to_s == "raw" ? to_raw : to_bmp
  end
end
