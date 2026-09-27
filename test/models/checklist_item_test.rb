require "test_helper"

class ChecklistItemTest < ActiveSupport::TestCase
  ZONE = ActiveSupport::TimeZone["America/New_York"]
  # Wednesday morning.
  NOW  = ZONE.parse("2026-09-16 09:00")

  def item(done_at)
    ChecklistItem.from("id" => "a", "text" => "Milk", "done_at" => done_at&.iso8601)
  end

  test "an item that was never checked isn't done" do
    %w[never daily weekly].each { assert_not item(nil).done?(reset: it, now: NOW) }
  end

  test "on a list that never resets, a checked item stays done" do
    assert item(NOW - 1.year).done?(reset: "never", now: NOW)
  end

  test "on a daily list, an item is done only if it was checked today, in the panel's zone" do
    assert item(ZONE.parse("2026-09-16 00:00")).done?(reset: "daily", now: NOW)
    assert_not item(ZONE.parse("2026-09-15 23:59")).done?(reset: "daily", now: NOW)
  end

  test "on a weekly list, an item is done only if it was checked since the week began" do
    Date.beginning_of_week = :sunday
    assert item(ZONE.parse("2026-09-13 08:00")).done?(reset: "weekly", now: NOW)
    assert_not item(ZONE.parse("2026-09-12 23:00")).done?(reset: "weekly", now: NOW)

    Date.beginning_of_week = :monday
    assert_not item(ZONE.parse("2026-09-13 08:00")).done?(reset: "weekly", now: NOW)
  ensure
    Date.beginning_of_week = :monday
  end

  test "an item needs some text, and not too much" do
    assert ChecklistItem.new(text: "x" * ChecklistItem::MAX_TEXT).valid?
    assert_not ChecklistItem.new(text: "  ").valid?

    long = ChecklistItem.new(text: "x" * (ChecklistItem::MAX_TEXT + 1))
    assert_not long.valid?
    assert_equal [ "Item is too long (maximum is 200 characters)" ], long.errors.full_messages
  end

  test "it round-trips as a hash" do
    hash = { "id" => "a", "text" => "Milk", "done_at" => "2026-09-16T13:00:00Z" }

    assert_equal hash, ChecklistItem.from(hash.merge("extra" => 1)).to_h
  end
end
