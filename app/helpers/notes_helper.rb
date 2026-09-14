# A note's phone page link, and the QR code a note tile draws of it.
module NotesHelper
  # The margin, in modules, that a scanner needs around a QR code.
  QR_QUIET_ZONE = 4

  # The phone page at the server address from Settings: a panel is often
  # rendered in a job with no request to take a host from, and a phone
  # needs an address it can reach. Until the address is set, the current
  # request's host.
  def note_phone_url(note)
    edit_note_url(note, **AppSetting.current.url_options.to_h)
  end

  # Black modules on white whatever the panel's theme, inside a quiet zone,
  # at a whole number of px per module so each lands on the pixel grid.
  def note_qr_code(note, module_px:)
    qr     = RQRCode::QRCode.new(note_phone_url(note), level: :m)
    offset = QR_QUIET_ZONE * module_px
    edge   = qr.modules.size * module_px + 2 * offset

    # rqrcode draws the modules from our own URL; there is no user text in it.
    modules = qr.as_svg(module_size: module_px, offset:, color: "000", use_path: true, standalone: false).html_safe

    tag.svg(width: edge, height: edge, xmlns: "http://www.w3.org/2000/svg", "shape-rendering": "crispEdges",
            role: "img", aria: { label: t("notes.qr_code_label") }) do
      safe_join([ tag.rect(width: edge, height: edge, fill: "#fff"), modules ])
    end
  end
end
