require "test_helper"

class Checklists::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @checklist = checklist_providers(:one)
    @source    = sources(:five)
  end

  def texts
    @checklist.reload.items.map { it["text"] }
  end

  test "adding an item puts it last, says so and writes the payload" do
    post checklist_items_url(@checklist), params: { item: { text: "Oat milk" } }

    assert_redirected_to edit_checklist_url(@checklist)
    assert_equal %w[Milk Eggs Bread Oat\ milk], texts
    assert_equal @checklist.fetch!, @source.reload.payload

    follow_redirect!
    assert_select ".alert[role=status]", /Added “Oat milk”/
  end

  test "a blank item is refused, on the page" do
    post checklist_items_url(@checklist), params: { item: { text: " " } }

    assert_response :unprocessable_content
    assert_select "ul.errors li", "Item can't be blank"
    assert_select "input#item_text.is-invalid"
    assert_equal 3, texts.size
  end

  test "a full list is refused, and the item stays in the field" do
    @checklist.update!(items: ChecklistProvider::MAX_ITEMS.times.map { { "id" => it.to_s, "text" => "x", "done_at" => nil } })

    post checklist_items_url(@checklist), params: { item: { text: "One more" } }

    assert_response :unprocessable_content
    assert_select "ul.errors li", "Checklist can have at most 50 items"
    assert_select "input#item_text[value=?]", "One more"
    assert_select "ul.checklist > li", ChecklistProvider::MAX_ITEMS
    assert_equal ChecklistProvider::MAX_ITEMS, texts.size
  end

  test "checking an item off" do
    freeze_time do
      patch checklist_item_url(@checklist, "milk"), params: { item: { done: "1" } }

      assert_redirected_to edit_checklist_url(@checklist)
      assert_equal Time.current.iso8601, @checklist.reload.items.first["done_at"]
      assert_equal @checklist.fetch!, @source.reload.payload
    end
  end

  test "sending the same change twice leaves it as asked" do
    2.times { patch checklist_item_url(@checklist, "milk"), params: { item: { done: "1" } } }
    assert @checklist.reload.done?("milk")

    2.times { patch checklist_item_url(@checklist, "eggs"), params: { item: { done: "0" } } }
    assert_not @checklist.reload.done?("eggs")
  end

  test "moving an item up or down, one place at a time" do
    patch move_checklist_item_url(@checklist, "bread"), params: { by: "-1" }
    assert_redirected_to edit_checklist_url(@checklist)
    assert_equal %w[Milk Bread Eggs], texts

    patch move_checklist_item_url(@checklist, "milk"), params: { by: "9" }
    assert_equal %w[Bread Milk Eggs], texts
  end

  test "removing an item says which" do
    delete checklist_item_url(@checklist, "eggs")

    assert_redirected_to edit_checklist_url(@checklist)
    assert_equal %w[Milk Bread], texts

    follow_redirect!
    assert_select ".alert[role=status]", /Removed “Eggs”/
  end

  test "changes made on the source's edit page go back there" do
    post checklist_items_url(@checklist), params: { item: { text: "Jam" }, back: "source" }
    assert_redirected_to edit_source_url(@source)

    patch checklist_item_url(@checklist, "milk"), params: { item: { done: "1" }, back: "source" }
    assert_redirected_to edit_source_url(@source)

    patch move_checklist_item_url(@checklist, "milk"), params: { by: "1", back: "source" }
    assert_redirected_to edit_source_url(@source)

    delete checklist_item_url(@checklist, "jam"), params: { back: "source" }
    assert_response :not_found

    delete checklist_item_url(@checklist, "bread"), params: { back: "source" }
    assert_redirected_to edit_source_url(@source)
    assert_equal %w[Eggs Milk Jam], texts
  end

  test "an item refused on the source's edit page shows that page again" do
    post checklist_items_url(@checklist), params: { item: { text: "" }, back: "source" }

    assert_response :unprocessable_content
    assert_select "#sidebar"
    assert_select "form[action=?] input[name=?]", source_path(@source), "source[name]"
    assert_select "section ul.errors li", "Item can't be blank"
  end

  test "an unknown item is not found" do
    patch checklist_item_url(@checklist, "nope"), params: { item: { done: "1" } }
    assert_response :not_found

    delete checklist_item_url(@checklist, "nope")
    assert_response :not_found
  end
end
