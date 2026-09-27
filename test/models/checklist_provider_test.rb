require "test_helper"

class ChecklistProviderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @checklist = checklist_providers(:one)
    @source    = sources(:five)
  end

  def texts
    @checklist.items.map { it["text"] }
  end

  test "fetch! hands the items and how they reset to the payload" do
    assert_equal({ "reset" => "never", "items" => @checklist.items }, @checklist.fetch!)
    assert_equal({ "reset" => "never", "items" => [] }, ChecklistProvider.new.fetch!)
  end

  test "its detail is how many are done" do
    assert_equal "1 of 3 done", @checklist.detail
  end

  test "items typed one per line are added in order, skipping blank lines" do
    checklist = ChecklistProvider.new(new_items: " Milk \n\nEggs\n")

    assert_equal %w[Milk Eggs], checklist.items.map { it["text"] }
    assert_equal " Milk \n\nEggs\n", checklist.new_items, "kept as typed for a form that can't be saved"
    assert_equal 2, checklist.items.map { it["id"] }.uniq.size
  end

  test "an added item is squished, unchecked and last" do
    @checklist.add_item("  Oat   milk ")

    assert_equal({ "text" => "Oat milk", "done_at" => nil }, @checklist.items.last.except("id"))
  end

  test "toggling checks an item that isn't done, and unchecks one that is" do
    freeze_time do
      @checklist.toggle_item("milk")
      @checklist.toggle_item("eggs")

      assert_equal Time.current.iso8601, @checklist.items.first["done_at"]
      assert_nil @checklist.items.second["done_at"]
      assert @checklist.done?("milk")
      assert_not @checklist.done?("eggs")
    end
  end

  test "on a daily list, an item checked yesterday is checked again, not unchecked" do
    @checklist.reset = "daily"
    assert_not @checklist.done?("eggs")

    freeze_time do
      @checklist.toggle_item("eggs")
      assert_equal Time.current.iso8601, @checklist.items.second["done_at"]
    end
  end

  test "items move up and down, stopping at either end" do
    @checklist.move_item("bread", -1)
    assert_equal %w[Milk Bread Eggs], texts

    @checklist.move_item("milk", -1)
    assert_equal %w[Milk Bread Eggs], texts

    @checklist.move_item("milk", 5)
    assert_equal %w[Bread Eggs Milk], texts

    @checklist.move_item("nope", 1)
    assert_equal %w[Bread Eggs Milk], texts
  end

  test "items are removed, and the done ones cleared" do
    @checklist.remove_item("bread")
    assert_equal %w[Milk Eggs], texts

    @checklist.clear_done
    assert_equal %w[Milk], texts
  end

  test "a list has a limit, and its items need text within theirs" do
    @checklist.items = []
    ChecklistProvider::MAX_ITEMS.times { @checklist.add_item("x") }
    assert @checklist.valid?

    @checklist.add_item("one more")
    assert_not @checklist.valid?
    assert_includes @checklist.errors.full_messages, "Checklist can have at most 50 items"

    @checklist.items = []
    @checklist.add_item(" ")
    @checklist.add_item("x" * (ChecklistItem::MAX_TEXT + 1))
    assert_not @checklist.valid?
    assert_equal [ "Checklist can't have a blank item", "Checklist items can be at most 200 characters" ],
                 @checklist.errors.full_messages
  end

  test "it resets never, daily or weekly" do
    assert_not ChecklistProvider.new(reset: "hourly").valid?
    %w[never daily weekly].each { assert ChecklistProvider.new(reset: it).valid? }
  end

  test "saving writes the payload at once, with no job, and asks the panels showing it for a new frame" do
    dashboards(:one).dashboard_items.create!(kind: "checklist", col: 5, row: 1, col_span: 4, row_span: 3,
                                             sources: [ @source ])
    at = Time.utc(2026, 9, 13, 12)

    travel_to(at) do
      assert_no_enqueued_jobs do
        @checklist.toggle_item("milk")
        @checklist.save!
      end
    end

    assert_equal @checklist.fetch!, @source.reload.payload
    assert_equal at, @source.fetched_at
    assert_equal at, devices(:one).reload.refresh_requested_at
    assert_not_equal at, devices(:two).reload.refresh_requested_at, "a panel showing another dashboard is left alone"
  end

  test "it changes when it's edited, not on a schedule" do
    assert_not ChecklistProvider.polls?
  end
end
