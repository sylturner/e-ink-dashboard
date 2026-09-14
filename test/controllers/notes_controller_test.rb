require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @note   = note_providers(:one)
    @source = sources(:four)
  end

  test "the phone page is the note's body, ready to edit" do
    get edit_note_url(@note)

    assert_response :success
    assert_select "title", @source.name
    assert_select "main#main-content h1", @source.name
    assert_select "form[action=?]", note_path(@note) do
      assert_select "label[for=note_body]", "Note"
      assert_select "textarea.form-control#note_body[name=?][aria-describedby=note_body_hint]", "note[body]", text: /Groceries/
      assert_select ".form-text#note_body_hint", /Markdown works/
      assert_select "details summary", "Formatting help"
      assert_select "details table th[scope=col]", 2
      assert_select "input[type=submit][value=?]", "Save note"
    end
  end

  # It shares the admin's head, but none of its navigation.
  test "the page is laid out for a phone" do
    get edit_note_url(@note)

    assert_select "html[lang=en]"
    assert_select "meta[name=viewport]"
    assert_select "meta[name=application-name][content=?]", I18n.t("app.name")
    assert_select "link[rel=stylesheet][href*=application]"
    assert_select "#sidebar, header.header, .skip-link", 0
  end

  test "saving the note says so and writes its payload" do
    patch note_url(@note), params: { note: { body: "Call the plumber" } }

    assert_redirected_to edit_note_url(@note)
    assert_equal "Call the plumber", @note.reload.body
    assert_equal({ "body" => "Call the plumber" }, @source.reload.payload)

    follow_redirect!
    assert_select ".alert[role=status]", /Note saved/
  end

  test "a body over the limit is refused" do
    patch note_url(@note), params: { note: { body: "x" * (NoteProvider::MAX_BODY + 1) } }

    assert_response :unprocessable_content
    assert_select "ul.errors li", /Body is too long/
    assert_select "textarea.is-invalid[name=?]", "note[body]"
    assert_match(/Groceries/, @note.reload.body)
  end

  test "an unknown note is not found" do
    get edit_note_url(id: 0)

    assert_response :not_found
  end

  test "a short link lands on the phone page" do
    get "/notes/#{@note.id}"

    assert_redirected_to "/notes/#{@note.id}/edit"
  end
end
