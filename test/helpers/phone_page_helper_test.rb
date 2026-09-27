require "test_helper"

class PhonePageHelperTest < ActionView::TestCase
  setup do
    @note      = note_providers(:one)
    @checklist = checklist_providers(:one)
  end

  test "the phone link uses the server address" do
    AppSetting.current.update!(server_url: "https://dashboard.example.com")

    assert_equal "https://dashboard.example.com/notes/#{@note.id}/edit", phone_page_url(@note)
    assert_equal "https://dashboard.example.com/checklists/#{@checklist.id}/edit", phone_page_url(@checklist)
  end

  test "without a server address, the phone link uses the request's host" do
    assert_equal "http://test.host/notes/#{@note.id}/edit", phone_page_url(@note)
  end

  test "a source with no phone page has no link" do
    assert_raises(ArgumentError) { phone_page_url(rss_providers(:one)) }
  end

  test "the QR code is black on white inside a quiet zone, at whole pixels" do
    AppSetting.current.update!(server_url: "http://192.168.1.10:3000")
    modules = RQRCode::QRCode.new(phone_page_url(@note), level: :m).modules.size
    edge    = ((modules + 2 * PhonePageHelper::QR_QUIET_ZONE) * 3).to_s

    @rendered = phone_page_qr_code(@note, module_px: 3)

    assert_select "svg[width=?][height=?][shape-rendering=crispEdges][role=img][aria-label=?]", edge, edge,
                  "QR code to edit this note" do
      assert_select "rect[width=?][height=?][fill='#fff']", edge, edge
      assert_select "path[fill='#000'][transform='translate(12,12) scale(3)']", 1
    end
  end

  test "a checklist's QR code says what it opens" do
    @rendered = phone_page_qr_code(@checklist, module_px: 2)

    assert_select "svg[aria-label=?]", "QR code to check off this list"
  end
end
