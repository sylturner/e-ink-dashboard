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

  test "raw HTML and images are dropped, and a link keeps only its text" do
    @rendered = markdown(<<~MD)
      <script>alert(1)</script>

      <img src=x onerror=alert(1)>

      ![a cat](https://example.com/cat.png) Call [the plumber](https://example.com)
    MD

    assert_select "script, img, a, [onerror], [src], [href]", 0
    assert_includes @rendered, "Call the plumber"
    assert_not_includes @rendered, "alert"
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
