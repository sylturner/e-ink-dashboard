# One line of a checklist (ChecklistProvider). The list keeps its items as
# hashes in a JSON column and in its source's payload; this reads one, and
# validates what someone types before it's added.
#
# An item keeps when it was checked rather than whether it is. A list that
# resets daily or weekly counts an item done only if it was checked since
# the day or week began, so it clears itself with nothing to run.
class ChecklistItem
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_TEXT = 200

  attribute :id, :string
  attribute :text, :string
  attribute :done_at, :datetime

  validates :text, presence: true, length: { maximum: MAX_TEXT }

  def self.from(hash)
    new(hash.to_h.slice("id", "text", "done_at"))
  end

  # Whether it's done at `now`, on a list that resets as `reset` says:
  # checked since the start of the day or week, or ever.
  def done?(reset:, now:)
    return false if done_at.nil?

    case reset
    when "daily"  then done_at >= now.beginning_of_day
    when "weekly" then done_at >= now.beginning_of_week
    else true
    end
  end

  def to_h
    { "id" => id, "text" => text, "done_at" => done_at&.iso8601 }
  end
end
