require "test_helper"

class NotesHelperTest < ActionView::TestCase
  setup do
    @note = note_providers(:one)
  end

  test "the phone link uses the server address" do
    AppSetting.current.update!(server_url: "https://dashboard.example.com")

    assert_equal "https://dashboard.example.com/notes/#{@note.id}/edit", note_phone_url(@note)
  end

  test "without a server address, the phone link uses the request's host" do
    assert_equal "http://test.host/notes/#{@note.id}/edit", note_phone_url(@note)
  end

  test "the QR code is black on white inside a quiet zone, at whole pixels" do
    AppSetting.current.update!(server_url: "http://192.168.1.10:3000")
    modules = RQRCode::QRCode.new(note_phone_url(@note), level: :m).modules.size
    edge    = ((modules + 2 * NotesHelper::QR_QUIET_ZONE) * 3).to_s

    @rendered = note_qr_code(@note, module_px: 3)

    assert_select "svg[width=?][height=?][shape-rendering=crispEdges][role=img][aria-label]", edge, edge do
      assert_select "rect[width=?][height=?][fill='#fff']", edge, edge
      assert_select "path[fill='#000'][transform='translate(12,12) scale(3)']", 1
    end
  end
end
