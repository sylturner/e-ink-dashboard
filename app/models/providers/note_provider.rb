# Markdown someone writes, on the source form or on the note's phone page
# (NotesController). There is nothing to fetch: fetch! only copies the
# body into the payload that tiles draw.
class NoteProvider < ApplicationRecord
  include Providable

  provides label:           "Note",
           icon:            "cil-notes",
           description:     "Markdown text you can edit from a phone.",
           attributes:      %i[body],
           # Only a safety net: saving the note writes the payload.
           refresh_seconds: 1.day.to_i,
           polls:           false

  MAX_BODY = 5_000

  validates :body, length: { maximum: MAX_BODY }

  # A note has nothing to wait on, so saving it writes the payload now
  # instead of queuing a FetchSourceJob. That job needs a worker, which
  # development doesn't run, and the tile stayed blank until one did.
  after_save_commit :refresh_source

  def detail
    body.to_s.squish.truncate(50)
  end

  def fetch!
    { "body" => body.to_s }
  end

  private

  # Runs on every save, not only a changed body, so saving again repairs
  # a payload that was never written.
  def refresh_source
    return if source.nil? || source.payload == fetch!

    source.record_success(fetch!)
    source.request_refresh!
  end
end
