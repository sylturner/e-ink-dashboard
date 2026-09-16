require "test_helper"

class NewspaperLayoutTest < ActiveSupport::TestCase
  test "every headline size has its render.css class, and each ladder steps down" do
    css = Rails.root.join("app/assets/stylesheets/render.css").read

    NewspaperLayout::ALL.each { |px| assert_includes css, ".hl-#{px} {", "no .hl-#{px}" }
    %i[NAME_SIZES LEAD_SIZES BIG_SIZES FEATURE_SIZES BRIEF_SIZES].each do |ladder|
      sizes = NewspaperLayout.const_get(ladder)
      assert_equal sizes.sort.reverse, sizes, "#{ladder} isn't largest first"
    end
  end

  test "every font render.css names is in app/assets/fonts" do
    css = Rails.root.join("app/assets/stylesheets/render.css").read

    css.scan(/url\("([^"]+\.(?:ttf|otf|woff2?))"\)/).flatten.each do |font|
      assert Rails.root.join("app/assets/fonts", font).exist?, "#{font} is missing"
    end
  end
end
