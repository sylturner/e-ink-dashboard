# app/services/frame.rb
class Frame
  attr_reader :width, :height, :rows

  def initialize(width:, height:, rows:)
    @width  = width
    @height = height
    @rows   = rows
  end

  # rows are top-down, 1 bit per pixel, MSB first, 1 = white
  def self.from_png(png_bytes, threshold: 128)
    image = ChunkyPNG::Image.from_blob(png_bytes)
    row_bytes = (image.width + 7) / 8

    rows = Array.new(image.height) do |y|
      buffer = Array.new(row_bytes, 0)
      image.width.times do |x|
        px = image[x, y]
        lum = (ChunkyPNG::Color.r(px) * 299 +
               ChunkyPNG::Color.g(px) * 587 +
               ChunkyPNG::Color.b(px) * 114) / 1000
        buffer[x / 8] |= (0x80 >> (x % 8)) if lum >= threshold
      end
      buffer.pack("C*")
    end

    new(width: image.width, height: image.height, rows: rows)
  end

  def to_raw
    rows.join
  end

  def to_bmp
    row_bytes = rows.first.bytesize
    offset    = 62
    size      = offset + row_bytes * height

    file = ["BM", size, 0, 0, offset].pack("a2VvvV")
    dib  = [40, width, height, 1, 1, 0,
            row_bytes * height, 2835, 2835, 2, 2].pack("Vl<l<vvVVl<l<VV")
    palette = [0, 0, 0, 0, 255, 255, 255, 0].pack("C8")

    file + dib + palette + rows.reverse.join
  end
end
