require "test_helper"

class MarkdownImagesTest < ActiveSupport::TestCase
  def upload(name = "cat.png", created_at: 2.days.ago)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: name).tap do
      it.update_column(:created_at, created_at)
    end
  end

  def png
    Vips::Image.black(20, 10).write_to_buffer(".png")
  end

  def markdown_for(blob)
    "![#{blob.filename.base}](/rails/active_storage/blobs/redirect/#{blob.signed_id}/#{blob.filename})"
  end

  test "finds the blob an image's path points to, and nothing else" do
    blob = upload

    assert_equal blob, MarkdownImages.blob_for("/rails/active_storage/blobs/redirect/#{blob.signed_id}/cat.png")
    assert_equal blob, MarkdownImages.blob_for("http://dash.local:3000/rails/active_storage/blobs/#{blob.signed_id}/cat.png")
    assert_nil MarkdownImages.blob_for("/rails/active_storage/blobs/redirect/forged/cat.png")
    assert_nil MarkdownImages.blob_for("https://example.com/cat.png")
    assert_nil MarkdownImages.blob_for(nil)
  end

  test "purges uploads no note or text tile uses, past their grace" do
    in_note, in_tile, unused, fresh = upload("a.png"), upload("b.png"), upload("c.png"), upload("d.png", created_at: 1.hour.ago)

    NoteProvider.first.update!(body: "Look:\n\n#{markdown_for(in_note)}")
    dashboard_items(:one).update!(kind: "text", view: "formatted", sources: [], settings: { "body" => markdown_for(in_tile) })

    assert_equal 1, MarkdownImages.purge_unused
    assert ActiveStorage::Blob.exists?(in_note.id)
    assert ActiveStorage::Blob.exists?(in_tile.id)
    assert ActiveStorage::Blob.exists?(fresh.id), "an upload not yet saved in a text is kept for a day"
    assert_not ActiveStorage::Blob.exists?(unused.id)
    assert_not unused.service.exist?(unused.key)
  end

  test "purges an unused image's variants with it" do
    blob = upload
    variant = blob.variant(resize_to_limit: [ 10, 10 ]).processed
    variant_blob = variant.image.blob

    assert_equal 1, MarkdownImages.purge_unused
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert_not ActiveStorage::Blob.exists?(variant_blob.id)
    assert_equal 0, ActiveStorage::VariantRecord.count
  end

  test "never purges an attached blob" do
    blob = upload
    ActiveStorage::Attachment.create!(name: "image", record: NoteProvider.first, blob:)

    assert_equal 0, MarkdownImages.purge_unused
    assert ActiveStorage::Blob.exists?(blob.id)
  end
end
