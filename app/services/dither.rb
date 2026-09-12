# app/services/dither.rb
#
# Error-diffusion dithering from 8-bit grayscale down to pure black and
# white. Each pixel snaps to 0 or 255 and the difference is pushed onto
# neighbors not yet visited, so mid-grays (photos, comics, anti-aliased
# edges) come out as dot patterns rather than solid blobs.
#
# Pixels that are already pure black or white carry no error, so the
# pixel-aligned dashboard text is left exactly as a plain threshold would.
class Dither
  # [dx, dy, weight] taps, relative to the current pixel, over `divisor`.
  KERNELS = {
    "floyd_steinberg" => {
      divisor: 16.0,
      taps: [ [ 1, 0, 7 ], [ -1, 1, 3 ], [ 0, 1, 5 ], [ 1, 1, 1 ] ]
    },
    # Only diffuses 6/8 of the error, which keeps contrast higher and
    # large flat areas cleaner. The classic original-Macintosh look.
    "atkinson" => {
      divisor: 8.0,
      taps: [ [ 1, 0, 1 ], [ 2, 0, 1 ], [ -1, 1, 1 ], [ 0, 1, 1 ], [ 1, 1, 1 ], [ 0, 2, 1 ] ]
    }
  }.freeze

  ALGORITHMS = KERNELS.keys.freeze

  # `pixels` is a width * height byte string of grayscale values. Returns
  # a string of the same size holding only 0 (black) and 255 (white).
  def self.call(pixels, width:, height:, algorithm: "floyd_steinberg", threshold: 128)
    kernel = KERNELS.fetch(algorithm.to_s) { raise ArgumentError, "unknown dither: #{algorithm}" }
    new(pixels, width, height, kernel, threshold).call
  end

  def initialize(pixels, width, height, kernel, threshold)
    @values    = pixels.unpack("C*").map(&:to_f)
    @width     = width
    @height    = height
    @taps      = kernel[:taps].map { |dx, dy, weight| [ dx, dy, weight / kernel[:divisor] ] }
    @threshold = threshold
  end

  def call
    output = Array.new(@width * @height, 0)

    @height.times do |y|
      # Serpentine scan: alternate direction each row so error does not
      # always drift the same way and streak diagonally.
      reverse = y.odd?
      xs = reverse ? (@width - 1).downto(0) : 0.upto(@width - 1)

      xs.each do |x|
        index = y * @width + x
        value = @values[index]
        white = value >= @threshold
        output[index] = 255 if white

        error = white ? value - 255 : value
        next if error.zero?

        @taps.each do |dx, dy, weight|
          nx = reverse ? x - dx : x + dx
          ny = y + dy
          next if nx.negative? || nx >= @width || ny >= @height

          @values[ny * @width + nx] += error * weight
        end
      end
    end

    output.pack("C*")
  end
end
