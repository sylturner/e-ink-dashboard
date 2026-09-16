require "test_helper"

class NewspaperStyleTest < ActiveSupport::TestCase
  def style(view, settings = {})
    NewspaperStyle.for(DashboardItem.new(kind: "newspaper", view:, settings:))
  end

  test "every style is a newspaper layout, and every preset font is a real one" do
    assert_equal NewspaperStyle::KEYS, Component.views("newspaper").keys

    NewspaperStyle::PRESETS.each do |key, config|
      NewspaperStyle::ROLES.each do |role|
        Array(config[role]).each do |font|
          assert font == NewspaperStyle::RANSOM || NewspaperFont.find(font), "#{key}'s #{role} is unknown #{font}"
        end
      end
    end
  end

  test "a slot's ladder steps down through whole multiples of each cut's grid" do
    broadsheet = style("broadsheet")

    assert_equal %w[jacquard12-63 jacquard24-43 jacquard12-42 jacquard12-21], broadsheet.ladder(:name)
    assert_equal %w[jersey15-54 jersey25-41 jersey20-34 jersey15-27], broadsheet.ladder(:lead)
    assert_equal %w[jersey15-27 pixel_operator_bold-16 bitrimus-16], broadsheet.ladder(:feature)
    assert_equal %w[jersey25-82 jersey15-81 jersey20-68 jersey15-54 jersey25-41 jersey20-34 jersey15-27], style("tabloid").ladder(:lead)
    assert_equal %w[home_video-60 home_video-40 home_video-20], style("zine").ladder(:lead), "the lead continues below 27px"
    assert_equal %w[jacquarda_bastarda-26 jacquarda_bastarda-13], style("wizard").ladder(:name), "set at half height, to be stretched"

    NewspaperStyle::KEYS.each do |key|
      %i[name lead big feature brief].each do |slot|
        style(key).ladder(slot).grep(/\A(.+)-(\d+)\z/) do
          cut = NewspaperFont::REGISTRY.values.flat_map(&:cuts).find { it.key == $1 }
          assert_equal 0, $2.to_i % cut.grid, "#{key} #{slot} sets #{cut.key} off its grid"
        end
      end
    end
  end

  test "a font with no size in a slot's range gives its smallest above it" do
    assert_equal %w[jersey15-27], style("custom", "subhead_font" => "jersey").ladder(:brief)
  end

  test "a custom style falls back to the broadsheet's fonts for anything unknown" do
    custom = style("custom", "headline_font" => "Kernel", "layout" => "sideways", "masthead_font" => "ransom")

    assert_equal style("broadsheet").ladder(:lead), custom.ladder(:lead)
    assert_equal "broadsheet", custom.layout
    assert custom.ransom?
    assert_not style("custom", "headline_font" => "ransom").ladder(:lead).include?("ransom")
    assert_equal "broadsheet", style("front_page").key, "an unknown layout reads as the broadsheet"
  end

  test "its stylesheet embeds only the cuts it uses, and none render.css already has" do
    css = style("zine").css("paper-1")

    assert_includes css, %(font-family: "np-home_video")
    assert_includes css, "url(data:font/woff2;base64,"
    assert_not_includes css, %(font-family: "np-pixantiqua"; src)
    assert_not_includes css, %(font-family: "PressStart2P"; src)
    assert_match(/#paper-1 \{ font: 400 16px\/16px "np-pixel_operator_mono"/, css)
  end

  test "a style that shifts letters writes whole-pixel shifts for each" do
    css = style("zine").css("paper-1")

    assert_equal "jumble", style("zine").letters
    assert_nil style("broadsheet").letters
    NewspaperStyle::LETTER_SHIFTS.fetch("jumble")[:shifts].each_with_index do |(right, down), index|
      assert_includes css, ".shift-jumble-#{index} { transform: translate(#{right}px, #{down}px); }"
    end
    assert_not_includes css, "background", "no letter inside a headline is inverted"
  end

  test "every letter shift is whole pixels, and every style's strip is one it can draw" do
    NewspaperStyle::LETTER_SHIFTS.each do |name, pattern|
      assert pattern[:shifts].flatten.all?(Integer), name
    end
    assert_equal "binary", style("hacker").strip
    assert_equal "motto", style("wizard").strip
    assert_nil style("broadsheet").strip
    assert_equal %w[press_start-24], style("hacker").send(:temperature).then { [ it.first.step(it.last) ] }
  end

  test "every font file is in app/assets/fonts, with a license beside it" do
    licenses = Rails.root.join("app/assets/fonts/licenses").children.map { it.basename(".txt").to_s }

    NewspaperFont::REGISTRY.each_value do |font|
      font.cuts.each do |cut|
        assert Rails.root.join("app/assets/fonts", cut.file).exist?, "#{cut.file} is missing"
      end
      stem = font.cuts.first.file[/\A[A-Za-z]+/].downcase
      assert licenses.any? { stem.start_with?(it.delete("-")) || it.delete("-").start_with?(stem) }, "no license for #{font.label}"
    end
  end

  test "every font render.css names is in app/assets/fonts" do
    css = Rails.root.join("app/assets/stylesheets/render.css").read

    css.scan(/url\("([^"]+\.(?:ttf|otf|woff2?))"\)/).flatten.each do |font|
      assert Rails.root.join("app/assets/fonts", font).exist?, "#{font} is missing"
    end
  end
end
