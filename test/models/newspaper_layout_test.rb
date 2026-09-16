require "test_helper"

class NewspaperLayoutTest < ActiveSupport::TestCase
  test "every size has its render.css class, and each ladder steps down in order" do
    css = Rails.root.join("app/assets/stylesheets/render.css").read

    NewspaperLayout::ORDER.each { |size| assert_includes css, ".hl-#{size} {", "no .hl-#{size}" }
    %i[NAME_SIZES LEAD_SIZES BIG_SIZES FEATURE_SIZES BRIEF_SIZES].each do |ladder|
      sizes = NewspaperLayout.const_get(ladder)
      assert_equal sizes.sort_by { NewspaperLayout::ORDER.index(it) || flunk("#{ladder} has unknown #{it}") }, sizes,
                   "#{ladder} isn't largest first"
    end
  end

  test "every font render.css names is in app/assets/fonts" do
    css = Rails.root.join("app/assets/stylesheets/render.css").read

    css.scan(/url\("([^"]+\.(?:ttf|otf|woff2?))"\)/).flatten.each do |font|
      assert Rails.root.join("app/assets/fonts", font).exist?, "#{font} is missing"
    end
  end
end
