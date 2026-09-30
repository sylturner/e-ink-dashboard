require "test_helper"

class TokenLineTest < ActiveSupport::TestCase
  VALUES = { "name" => "Kitchen", "state" => "21", "empty" => "" }.freeze

  def fill(format)
    TokenLine.fill(format) { VALUES[it] }
  end

  test "fills each token from the block" do
    assert_equal "Kitchen: 21°", fill("{name}: {state}°")
  end

  test "drops the separators an empty token leaves, and a line of empty tokens" do
    assert_equal "Kitchen", fill("{name} · {empty}")
    assert_nil fill("Now: {empty} {missing}")
    assert_nil fill("No tokens at all")
  end
end
