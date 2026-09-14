require "test_helper"

class NoteProviderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @note   = note_providers(:one)
    @source = sources(:four)
  end

  # On dashboard one, which devices(:one) shows.
  def put_note_on_a_dashboard
    dashboards(:one).dashboard_items.create!(kind: "note", col: 5, row: 1, col_span: 4, row_span: 3, sources: [ @source ])
  end

  test "fetch! hands the body to the payload" do
    assert_equal({ "body" => @note.body }, @note.fetch!)
    assert_equal({ "body" => "" }, NoteProvider.new.fetch!)
  end

  test "its detail is the body on one line" do
    assert_equal "**Groceries** - [ ] milk - [x] eggs", @note.detail
  end

  test "a body has a limit" do
    @note.body = "x" * NoteProvider::MAX_BODY
    assert @note.valid?

    @note.body += "x"
    assert_not @note.valid?
  end

  # Development runs no job worker, so a queued fetch left the tile blank.
  test "saving a new body writes the payload at once, with no job" do
    freeze_time do
      assert_no_enqueued_jobs do
        @note.update!(body: "Call the plumber")
      end

      @source.reload
      assert_equal({ "body" => "Call the plumber" }, @source.payload)
      assert_equal Time.current, @source.fetched_at
    end
  end

  test "saving a new body asks the panels showing it for a new frame" do
    put_note_on_a_dashboard
    at = Time.utc(2026, 9, 13, 12)

    travel_to(at) { @note.update!(body: "Call the plumber") }

    assert_equal at, devices(:one).reload.refresh_requested_at
    assert_not_equal at, devices(:two).reload.refresh_requested_at, "a panel showing another dashboard is left alone"
  end

  test "saving a note that hasn't changed asks for nothing" do
    put_note_on_a_dashboard

    assert_no_changes -> { [ devices(:one).reload.refresh_requested_at, @source.reload.fetched_at ] } do
      @note.update!(updated_at: 1.hour.from_now)
    end
  end

  test "saving again fills in a payload that was never written" do
    @source.update_columns(payload: {}, fetched_at: nil)

    NoteProvider.find(@note.id).save!

    assert_equal({ "body" => @note.body }, @source.reload.payload)
    assert @source.healthy?
  end

  test "it changes when it's edited, not on a schedule" do
    assert_not NoteProvider.polls?
    assert RssProvider.polls?
  end
end
