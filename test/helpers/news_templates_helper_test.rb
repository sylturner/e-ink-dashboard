require "test_helper"

class NewsTemplatesHelperTest < ActionView::TestCase
  test "lists the paths feeds carry, most common first, leaving out the named tokens" do
    sources(:three).update!(payload: { "items" => [
      { "fields" => { "title" => "A", "category" => "World", "dc:creator" => "Ada" } },
      { "fields" => { "title" => "B", "category" => "Science" } },
      { "fields" => "junk" },
      "junk"
    ] })

    assert_equal %w[category dc:creator], feed_field_paths([ sources(:three), sources(:one) ])
  end

  test "every choice has a label" do
    labels = news_template_field_options + news_template_placement_options +
             news_template_image_size_options + news_template_line_size_options

    labels.each { |label, value| assert_no_match(/translation missing/i, label, value) }
  end
end
