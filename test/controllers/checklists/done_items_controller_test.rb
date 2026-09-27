require "test_helper"

class Checklists::DoneItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @checklist = checklist_providers(:one)
  end

  test "clearing the done items says how many went" do
    delete checklist_done_items_url(@checklist)

    assert_redirected_to edit_checklist_url(@checklist)
    assert_equal %w[Milk Bread], @checklist.reload.items.map { it["text"] }
    assert_equal @checklist.fetch!, sources(:five).reload.payload

    follow_redirect!
    assert_select ".alert[role=status]", /Cleared 1 done item\./
  end

  test "clearing from the source's edit page goes back there" do
    delete checklist_done_items_url(@checklist), params: { back: "source" }

    assert_redirected_to edit_source_url(sources(:five))
  end
end
