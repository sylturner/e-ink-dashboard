require "test_helper"

class ChecklistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @checklist = checklist_providers(:one)
    @source    = sources(:five)
  end

  test "the phone page lists the items, each a toggle with its own buttons" do
    get edit_checklist_url(@checklist)

    assert_response :success
    assert_select "title", @source.name
    assert_select "main#main-content h1", @source.name
    assert_select "main p", /1 of 3 done/
    assert_select "ul.checklist[aria-label=Items] > li", 3 do |rows|
      assert_select rows.first, "form[action=?] button.checklist-toggle[aria-pressed=false]", checklist_item_path(@checklist, "milk"), text: /Milk/
      assert_select rows.first, "input[name='item[done]'][value='1']"
      assert_select rows.first, "button[aria-label=?][disabled]", "Move “Milk” up"
      assert_select rows.first, "button[aria-label=?]:not([disabled])", "Move “Milk” down"
      assert_select rows.first, "form[action=?] input[name=_method][value=delete]", checklist_item_path(@checklist, "milk")
      assert_select rows[1], "button.checklist-toggle[aria-pressed=true]", text: /Eggs/
      assert_select rows[1], "input[name='item[done]'][value='0']"
      assert_select rows.last, "button[aria-label=?][disabled]", "Move “Bread” down"
    end
    assert_select "form[action=?]", checklist_items_path(@checklist) do
      assert_select "label[for=item_text]", "Add an item"
      assert_select "input#item_text[name=?][maxlength='200'][required][aria-describedby=item_text_hint]", "item[text]"
      assert_select "input[type=submit][value=Add]"
    end
    assert_select "form[action=?] button", checklist_done_items_path(@checklist), text: "Clear done items"
  end

  test "the page is laid out for a phone, and keeps its place when it changes" do
    get edit_checklist_url(@checklist)

    assert_select "meta[name=viewport]"
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "[data-controller=checklist-focus]"
    assert_select "#sidebar, header.header, .skip-link", 0
  end

  test "an empty list says so, and offers nothing to clear" do
    @checklist.update!(items: [])

    get edit_checklist_url(@checklist)

    assert_select "ul.checklist", 0
    assert_select "p", "Nothing on the list yet."
    assert_select "button", text: "Clear done items", count: 0
  end

  test "a list that starts over says when" do
    @checklist.update!(reset: "weekly")

    get edit_checklist_url(@checklist)

    assert_select "main p", /0 of 3 done\.\s+Starts over each week\./
  end

  test "an unknown checklist is not found" do
    get edit_checklist_url(id: 0)

    assert_response :not_found
  end

  test "a short link lands on the phone page" do
    get "/checklists/#{@checklist.id}"

    assert_redirected_to "/checklists/#{@checklist.id}/edit"
  end
end
