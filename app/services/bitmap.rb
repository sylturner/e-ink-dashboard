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
  # the capture is already almost pure black and white. With `dither:`
  # (see Dither::ALGORITHMS) the grays that remain — images, anti-aliased
  # curves — are error-diffused into dot patterns. Without it, every pixel
  # just falls to whichever side of `threshold` it is on.
  def self.from_png(png_bytes, bit_depth: 1, dither: nil, threshold: 128)
    raise ArgumentError, "only 1-bit is implemented" unless bit_depth == 1

    # Flatten onto white first, so transparent areas don't read as black.
    image  = Vips::Image.new_from_buffer(png_bytes, "")
    image  = image.flatten(background: 255) if image.has_alpha?
    image  = image.colourspace("b-w").extract_band(0).cast("uchar")
    width  = image.width
    height = image.height

    # Either way this is a uchar mask: 255 where white, else 0.
    pixels = if dither.present?
      Dither.call(image.write_to_memory, width: width, height: height,
                  algorithm: dither, threshold: threshold)
    else
      (image >= threshold).write_to_memory
    end
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
