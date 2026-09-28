require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  test "draws the Markdown a note is written in" do
    @rendered = markdown("# Groceries\n\n**milk** and *eggs*, not ~~bread~~\n\n- one\n- two\n\n> quoted\n\n---")

    assert_select "h1", "Groceries"
    assert_select "p strong", "milk"
    assert_select "p em", "eggs"
    assert_select "p del", "bread"
    assert_select "ul li", 2
    assert_select "blockquote p", "quoted"
    assert_select "hr", 1
  end

  test "a line break typed on a phone stays a line break" do
    @rendered = markdown("milk\neggs")

    assert_select "p br", 1
  end

  test "a task list draws checkboxes" do
    @rendered = markdown("- [ ] milk\n- [x] eggs")

    assert_select "li input[type=checkbox]", 2
    assert_select "li input[type=checkbox][checked]", 1
  end

  test "raw HTML is dropped, and a link keeps only its text" do
    @rendered = markdown(<<~MD)
      <script>alert(1)</script>

      <img src=x onerror=alert(1)>

      Call [the plumber](https://example.com)
    MD

    assert_select "script, img, a, [onerror], [href]", 0
    assert_includes @rendered, "Call the plumber"
    assert_not_includes @rendered, "alert"
  end

  test "an image on the web is drawn from there" do
    @rendered = markdown("![a cat](https://example.com/cat.png)")

    assert_select "img[src=?][alt=?]", "https://example.com/cat.png", "a cat"
  end

  test "an uploaded image is drawn inline, in color, no larger than a panel" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png(1600, 400)), filename: "wide.png")
    @rendered = markdown("![wide](/rails/active_storage/blobs/redirect/#{blob.signed_id}/wide.png)")

    src = css_select("img").sole["src"]
    assert_match %r{\Adata:image/png;base64,}, src
    image = Vips::Image.new_from_buffer(Base64.decode64(src.split(",", 2).last), "")
    assert_equal [ 800, 200 ], [ image.width, image.height ]
    assert_equal 3, image.bands, "Bitmap grays the whole frame, so the image needn't be"
  end

  test "an image that can't be drawn is dropped" do
    text = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("hi"), filename: "a.txt")
    @rendered = markdown(<<~MD)
      ![text](/rails/active_storage/blobs/redirect/#{text.signed_id}/a.txt)
      ![forged](/rails/active_storage/blobs/redirect/nope/x.png)
      ![local](/secret.png) ![inline](data:image/png;base64,AAAA)
    MD

    assert_select "img", 0
  end

  test "a font marker sets text in that font, with its face and class once" do
    @rendered = markdown("{font:jersey}Hello{/font} and {font:jersey}again{/font}\n\n{font:silkscreen}shared{/font}")

    assert_select "p span.md-font--jersey", 2
    assert_select "p span.md-font--jersey", "Hello"
    assert_select "style", 1
    style = css_select("style").sole.text
    assert_equal 1, style.scan(%(font-family: "np-jersey15"; src:)).size
    assert_includes style, ".md-font--jersey { font-family: \"np-jersey15\""
    assert_includes style, "--md-grid: 27px;"
    assert_no_match(/font-family: "Silkscreen"; src:/, style, "render.css already declares it")
  end

  test "a size marker scales the text, and nests with a font either way" do
    @rendered = markdown("{size:large}{font:tiny5}big{/font}{/size} {font:tiny5}{size:huge}bigger{/size}{/font}")

    assert_select "span.md-size--large > span.md-font--tiny5", "big"
    assert_select "span.md-font--tiny5 > span.md-size--huge", "bigger"
  end

  test "markers inside formatting and around it both work" do
    @rendered = markdown("**{font:jersey}bold{/font}** {size:small}_quiet_{/size}")

    assert_select "strong span.md-font--jersey", "bold"
    assert_select "span.md-size--small em", "quiet"
  end

  test "a marker that names nothing, isn't closed or spans paragraphs is drawn as typed" do
    @rendered = markdown("{font:comic_sans}a{/font} {size:giant}b{/size} {font:jersey}c\n\nd{/font} {size:large}e")

    assert_select "span", 0
    assert_select "style", 0
    assert_includes @rendered, "{font:comic_sans}a{/font}"
    assert_includes @rendered, "{size:giant}b{/size}"
    assert_includes @rendered, "{font:jersey}c"
    assert_includes @rendered, "{size:large}e"
  end

  test "a marker can't smuggle markup in" do
    @rendered = markdown(%({font:jersey}<script>x()</script><b onclick="y">z</b>{/font}))

    assert_select "script, [onclick]", 0
  end

  def png(width, height)
    Vips::Image.black(width, height, bands: 3).add([ 200, 10, 10 ]).cast(:uchar).write_to_buffer(".png")
  end

  test "quotes stay straight and shortcodes stay text, for the panel's fonts" do
    @rendered = markdown(%(Say "hi" :tada:))

    assert_includes @rendered, ":tada:"
    assert_not_includes @rendered, "“"
  end

  test "headings carry no anchors" do
    @rendered = markdown("## Chores")

    assert_select "h2", "Chores"
    assert_select "h2 *", 0
  end

  test "no body draws nothing" do
    assert_equal "", markdown(nil)
  end
end
