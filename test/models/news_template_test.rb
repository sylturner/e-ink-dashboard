require "test_helper"

class NewsTemplateTest < ActiveSupport::TestCase
  ENTRY = {
    "title" => "Big news", "source" => "The Paper", "author" => "", "summary" => "What happened",
    "fields" => { "dc:creator" => "Ada", "category" => "World, Science" }
  }.freeze

  test "the default draws the title on two lines and nothing else" do
    template = NewsTemplate.default

    assert_not template.image.shown?
    assert_equal [ "{title}" ], template.lines.select(&:shown?).map(&:tokens)
    assert_equal [ 2, nil ], template.lines.first.then { [ it.clamp, it.size_class ] }
  end

  test "reads a form's numbered lines" do
    template = NewsTemplate.from(ActionController::Parameters.new(
      "image" => { "placement" => "left", "size" => "large" },
      "lines" => { "1" => { "field" => "custom", "format" => "  {source}  ·  {age} ", "size" => "small", "clamp" => "1" },
                   "0" => { "field" => "summary", "size" => "large", "clamp" => "3" } }
    ))

    assert_equal [ 120, 120 ], template.image.dimensions
    assert_equal [ "{summary}", "{source} · {age}" ], template.lines.first(2).map(&:tokens)
    assert_equal [ "t-md", 3 ], [ template.lines.first.size_class, template.lines.first.clamp ]
    assert_equal NewsTemplate::LINE_COUNT, template.lines.size
    assert_equal template, NewsTemplate.from(template.to_h)
  end

  test "anything it doesn't recognize falls back to the default" do
    template = NewsTemplate.from("image" => { "placement" => "behind", "size" => 9 },
                                 "lines" => [ { "field" => "send", "size" => "huge", "clamp" => "12" }, "junk" ])

    assert_equal NewsTemplate.default, template
    assert_equal NewsTemplate.default, NewsTemplate.from("not a hash")
  end

  test "a picture above the text spans the row" do
    assert_equal [ nil, 80 ], NewsTemplate.from("image" => { "placement" => "above" }).image.dimensions
  end

  test "fills named tokens, then paths into the item's fields" do
    assert_equal "Big news by Ada", NewsTemplate.fill("{title} by {dc:creator}", ENTRY)
    assert_equal "World, Science", NewsTemplate.fill("{category}", ENTRY)
    assert_equal "2h", NewsTemplate.fill("{age}", ENTRY, named: { "age" => "2h" })
  end

  test "drops the separators an empty token leaves, and a line with nothing to draw" do
    assert_equal "The Paper", NewsTemplate.fill("{author} · {source} · {missing}", ENTRY)
    assert_nil NewsTemplate.fill("By {author} {missing}", ENTRY)
    assert_nil NewsTemplate.fill("{title}", ENTRY.except("title").merge("fields" => "junk"))
  end
end
