require "test_helper"

class PurgeUnusedImagesJobTest < ActiveJob::TestCase
  test "purges the images no text uses" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "old.png")
    blob.update_column(:created_at, 2.days.ago)

    PurgeUnusedImagesJob.perform_now

    assert_not ActiveStorage::Blob.exists?(blob.id)
  end
end
