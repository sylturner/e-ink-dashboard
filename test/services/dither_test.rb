require "test_helper"

class DitherTest < ActiveSupport::TestCase
  def flat(value, width:, height:)
    ([ value ] * (width * height)).pack("C*")
  end

  Dither::ALGORITHMS.each do |algorithm|
    test "#{algorithm} leaves pure black and white untouched" do
      pixels = ([ 0, 255, 255, 0 ] * 4).pack("C*")

      assert_equal pixels, Dither.call(pixels, width: 4, height: 4, algorithm: algorithm)
    end

    test "#{algorithm} only emits black or white" do
      pixels = (0...64).map { |i| i * 4 }.pack("C*")
      output = Dither.call(pixels, width: 8, height: 8, algorithm: algorithm)

      assert_equal 64, output.bytesize
      assert_equal [ 0, 255 ], output.bytes.uniq.sort
    end
  end

  test "floyd_steinberg renders mid-grey as roughly half white" do
    output = Dither.call(flat(128, width: 32, height: 32), width: 32, height: 32)
    white  = output.bytes.count(255)

    assert_in_delta 512, white, 16
  end

  test "rejects an unknown algorithm" do
    assert_raises(ArgumentError) { Dither.call(flat(0, width: 1, height: 1), width: 1, height: 1, algorithm: "bogus") }
  end
end
