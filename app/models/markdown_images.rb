# Images the Markdown editor uploads (markdown_editor_controller.js). They
# aren't attached to the note or tile that shows them: Markdown refers to
# each by the path the editor inserts,
# /rails/active_storage/blobs/redirect/<signed id>/<filename>. So nothing
# removes one when its text does, and PurgeUnusedImagesJob clears out the
# ones no text refers to any more.
module MarkdownImages
  # The largest image that can be uploaded. The editor checks before
  # uploading, and a blob larger than this can't be created
  # (config/initializers/active_storage.rb).
  MAX_BYTES = 10.megabytes

  # How long an upload is kept before a saved text refers to it: an image
  # added to a note that hasn't been saved yet.
  GRACE = 1.day

  # The path anywhere in a text, and an <img> src that is one.
  PATH = %r{(?:https?://[^/\s)"]+)?/rails/active_storage/blobs/(?:redirect/|proxy/)?([^/\s)"]+)/}
  SRC  = /\A#{PATH}/

  class << self
    # The uploaded image an <img> src points to, or nil.
    def blob_for(src)
      signed_id = src.to_s[SRC, 1] or return
      ActiveStorage::Blob.find_signed(signed_id)
    end

    # Every Markdown text an uploaded image can be in.
    def texts
      NoteProvider.pluck(:body) +
        DashboardItem.where(kind: Component.markdown_kinds).pluck(:settings).map { it.to_h["body"] }
    end

    # The ids of the blobs saved texts refer to.
    def referenced_blob_ids
      texts.compact.flat_map { it.scan(PATH).flatten }.uniq
           .filter_map { ActiveStorage::Blob.find_signed(it)&.id }
    end

    # Removes the uploads no text refers to, once they're past their grace.
    # Only unattached blobs: a variant's is attached to its record.
    def purge_unused(before: GRACE.ago)
      unused = ActiveStorage::Blob.unattached.where(created_at: ...before).where.not(id: referenced_blob_ids)
      unused.find_each.count { purge(it) }
    end

    # A blob and its variants. Blob#purge alone gives up on a blob that has
    # variants: their records hold a foreign key to it.
    def purge(blob)
      blob.variant_records.find_each do |record|
        record.image.purge
        record.delete
      end
      blob.purge
      true
    end
  end
end
