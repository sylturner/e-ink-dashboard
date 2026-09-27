# A list someone checks off, from its phone page (ChecklistsController) or
# the source form. There is nothing to fetch: like NoteProvider, saving it
# writes the payload that tiles draw.
#
# It can start over each day or week (RESETS). Nothing runs to uncheck the
# items: each keeps when it was checked, and one checked before the day or
# week began counts as not done (ChecklistItem#done?).
class ChecklistProvider < ApplicationRecord
  include Providable

  provides label:           "Checklist",
           icon:            "cil-task",
           description:     "A list you check off from a phone, optionally starting over each day or week.",
           attributes:      %i[reset],
           # Only a safety net: saving the list writes the payload.
           refresh_seconds: 1.day.to_i,
           polls:           false

  MAX_ITEMS = 50
  RESETS    = %w[never daily weekly].freeze

  validates :reset, inclusion: { in: RESETS }
  validate :items_fit

  # See NoteProvider: saving writes the payload now rather than queuing a
  # FetchSourceJob.
  after_save_commit :refresh_source

  # The source form's box of items to add, one per line.
  def self.extra_params
    %i[new_items]
  end

  # Kept as typed, so a form that can't be saved shows it again.
  attr_reader :new_items

  def new_items=(lines)
    @new_items = lines
    lines.to_s.lines.map(&:strip).compact_blank.each { add_item(it) }
  end

  def entries
    items.map { ChecklistItem.from(it) }
  end

  def detail
    total = items.size
    done  = entries.count { it.done?(reset:, now: Time.current) }
    "#{done} of #{total} done"
  end

  def fetch!
    { "reset" => reset, "items" => items }
  end

  # --- Changes. Each only changes the record; the caller saves it. ---

  def add_item(text)
    self.items = items + [ { "id" => SecureRandom.hex(4), "text" => text.to_s.squish, "done_at" => nil } ]
  end

  # Checks an item that isn't done at `now`, and unchecks one that is.
  def toggle_item(id, now: Time.current)
    change_item(id) do |item|
      entry = ChecklistItem.from(item)
      item.merge("done_at" => entry.done?(reset:, now:) ? nil : now.iso8601)
    end
  end

  def remove_item(id)
    self.items = items.reject { it["id"] == id }
  end

  # Moves an item `by` places, up (negative) or down, stopping at either end.
  def move_item(id, by)
    from = items.index { it["id"] == id } or return
    to   = (from + by.to_i).clamp(0, items.size - 1)

    self.items = items.dup.tap { it.insert(to, it.delete_at(from)) }
  end

  def clear_done(now: Time.current)
    self.items = items.reject { ChecklistItem.from(it).done?(reset:, now:) }
  end

  def done?(id, now: Time.current)
    entries.find { it.id == id }&.done?(reset:, now:) || false
  end

  def item?(id)
    items.any? { it["id"] == id }
  end

  private

  def change_item(id)
    self.items = items.map { it["id"] == id ? yield(it) : it }
  end

  def items_fit
    errors.add(:items, :too_many, count: MAX_ITEMS) if items.size > MAX_ITEMS

    errors.add(:items, :blank_item) if entries.any? { it.text.blank? }
    errors.add(:items, :long_item, count: ChecklistItem::MAX_TEXT) if entries.any? { it.text.to_s.length > ChecklistItem::MAX_TEXT }
  end

  # Runs on every save, not only a change, so saving again repairs a
  # payload that was never written.
  def refresh_source
    return if source.nil? || source.payload == fetch!

    source.record_success(fetch!)
    source.request_refresh!
  end
end
