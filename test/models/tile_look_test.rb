require "test_helper"

class TileLookTest < ActiveSupport::TestCase
  test "a blank look leaves everything to the theme" do
    [ nil, {}, "nonsense", { "border" => "", "font" => "" } ].each do |value|
      look = TileLook.new(value)

      assert look.default?
      assert_empty look.classes
      assert_empty look.types
    end
  end

  test "each choice becomes a class, in a fixed order" do
    look = TileLook.new("scale" => "large", "border" => "double", "header" => "rule",
                        "padding" => "roomy", "align" => "middle", "invert" => "1")

    assert_equal %w[look--border-double look--header-rule look--padding-roomy look--align-middle
                    look--scale-large look--invert], look.classes
    assert_not look.default?
  end

  test "choices it doesn't offer are dropped" do
    look = TileLook.new("border" => "wavy", "header" => "<script>", "font" => "comic_sans", "invert" => "0")

    assert look.default?
    assert_nil look["border"]
    assert_nil look["font"]
    assert_equal false, look["invert"]
  end

  test "a font is set at the multiple of its grid nearest the text size" do
    # Pixel Operator's grid is 16px.
    assert_equal [ 16 ], TileLook.new("font" => "pixel_operator").types.map { it[:size] }
    assert_equal [ 16 ], TileLook.new("font" => "pixel_operator", "scale" => "small").types.map { it[:size] }
    assert_equal [ 32 ], TileLook.new("font" => "pixel_operator", "scale" => "large").types.map { it[:size] }

    # Jersey's smallest cut is 27px, the nearest it comes to 16.
    type = TileLook.new("font" => "jersey").types.sole
    assert_equal [ "jersey15", 27, "body" ], [ type[:cut].key, type[:size], type[:role] ]
    assert_includes TileLook.new("font" => "jersey").classes, "look--body-jersey15-27"
  end

  test "a header font is set near the header's size whatever the text size" do
    type = TileLook.new("header_font" => "tiny5", "scale" => "large").types.sole

    assert_equal [ "header", 16 ], type.values_at(:role, :size)
  end

  test "css embeds each face once and skips faces render.css declares" do
    looks = [ TileLook.new("font" => "tiny5"), TileLook.new("header_font" => "tiny5"),
              TileLook.new("font" => "silkscreen") ]
    css = TileLook.css(looks)

    assert_equal 1, css.scan("@font-face").size
    assert_includes css, %(font-family: "np-tiny5")
    assert_includes css, %(.card.look--body-tiny5-16 { --body-font: "np-tiny5", monospace; --body-fs: 16px; --body-lh: 17px; font-weight: 400; })
    assert_includes css, %(.card.look--header-tiny5-16 { --header-font: "np-tiny5")
    assert_includes css, %(--body-font: "Silkscreen")
  end

  test "css is empty when no tile sets a font" do
    assert_equal "", TileLook.css([ TileLook.new("border" => "thick") ])
  end
end
