# The Markdown editor's size limit, enforced when the blob is created, before
# anything is uploaded: a direct upload declares its size, and the Disk
# service refuses a body that doesn't match what was declared.
ActiveSupport.on_load(:active_storage_blob) do
  validates :byte_size, numericality: { less_than_or_equal_to: MarkdownImages::MAX_BYTES }, on: :create
end
