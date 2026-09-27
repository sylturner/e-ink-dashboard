require "test_helper"

class NewspaperFontTest < ActiveSupport::TestCase
  test "the admin's font previews are generated from the registry and current" do
    assert_equal NewspaperFont.preview_css, Rails.root.join("app/assets/stylesheets/font_previews.css").read,
                 "run bin/rails fonts:previews"
  end

  test "every font previews in its own face, from a file that exists" do
    css = NewspaperFont.preview_css

    NewspaperFont::REGISTRY.each_value do |font|
      cut, = font.nearest(NewspaperFont::PREVIEW_SIZE)
      assert_includes css, %(.#{font.preview_class} { font-family: "#{cut.family}")
      assert Rails.root.join("app/assets/fonts", cut.file).exist?, cut.file
    end
  end

  test "nearest picks a whole multiple of a cut's grid, the larger on a tie" do
    assert_equal [ "pixel_operator", 16 ], NewspaperFont.find("pixel_operator").nearest(16).then { [ it.first.key, it.last ] }
    assert_equal 32, NewspaperFont.find("pixel_operator").nearest(24).last
    assert_equal [ "jersey15", 27 ], NewspaperFont.find("jersey").nearest(16).then { [ it.first.key, it.last ] }
    assert_equal [ "jersey20", 34 ], NewspaperFont.find("jersey").nearest(34).then { [ it.first.key, it.last ] }
  end

  test "a Markdown font class scales by its grid, at its size nearest the text's by default" do
    css = NewspaperFont.find("silkscreen").markdown_css

    assert_includes css, ".md-font--silkscreen {"
    assert_includes css, "--md-grid: 8px;"
    assert_includes css, "font-size: calc(8px * var(--md-scale, 2));"
  end
end
