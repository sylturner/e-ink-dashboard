# What a checklist tile draws (renders/items/_checklist).
module ChecklistsHelper
  # The payload's items at `now`, each with whether it's done, in the order
  # the tile's Done items setting asks for (Component::CHECKLIST_DONE_ITEMS).
  def checklist_rows(data, done_items:, now:)
    reset = data["reset"]
    rows  = Array(data["items"]).map do |hash|
      entry = ChecklistItem.from(hash)
      [ entry, entry.done?(reset:, now:) ]
    end

    case done_items
    when "hide"   then rows.reject(&:last)
    when "bottom" then rows.partition { !it.last }.flatten(1)
    else rows
    end
  end
end
