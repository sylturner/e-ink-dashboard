require "test_helper"

class ChecklistsHelperTest < ActionView::TestCase
  NOW = Time.utc(2026, 9, 16, 12)

  setup do
    @data = sources(:five).payload # milk, eggs (done), bread
  end

  def rows(done_items, data: @data)
    checklist_rows(data, done_items:, now: NOW).map { |entry, done| [ entry.text, done ] }
  end

  test "done items are struck through where they are" do
    assert_equal [ [ "Milk", false ], [ "Eggs", true ], [ "Bread", false ] ], rows("strike")
  end

  test "done items move to the bottom, each group in its own order" do
    assert_equal [ [ "Milk", false ], [ "Bread", false ], [ "Eggs", true ] ], rows("bottom")
  end

  test "done items can be left off" do
    assert_equal [ [ "Milk", false ], [ "Bread", false ] ], rows("hide")
  end

  test "a list that resets draws yesterday's items as not done" do
    assert_equal [ false, false, false ], rows("strike", data: @data.merge("reset" => "daily")).map(&:last)
  end

  test "an empty payload has no rows" do
    assert_empty rows("strike", data: {})
  end
end
