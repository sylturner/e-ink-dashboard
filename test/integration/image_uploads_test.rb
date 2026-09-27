require "test_helper"

# The Markdown editor uploads images through Active Storage's direct
# uploads; its size limit holds on the server as well.
class ImageUploadsTest < ActionDispatch::IntegrationTest
  def direct_upload(byte_size)
    post rails_direct_uploads_path, as: :json, params: { blob: {
      filename: "cat.png", byte_size:, checksum: Digest::MD5.base64digest("x"), content_type: "image/png"
    } }
  end

  test "an image up to the limit can be uploaded" do
    assert_difference -> { ActiveStorage::Blob.count } do
      direct_upload(MarkdownImages::MAX_BYTES)
    end
    assert_response :success
    assert response.parsed_body.dig("direct_upload", "url")
  end

  test "an image over the limit is refused before it's uploaded" do
    assert_no_difference -> { ActiveStorage::Blob.count } do
      direct_upload(MarkdownImages::MAX_BYTES + 1)
    end
    assert_response :unprocessable_content
  end
end
