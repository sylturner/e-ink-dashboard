# The phone pages a note's or a checklist's tile links to, and the QR code
# a tile draws of one.
module PhonePageHelper
  # The margin, in modules, that a scanner needs around a QR code.
  QR_QUIET_ZONE = 4

  # A provider's phone page at the server address from Settings: a panel
  # is often rendered in a job with no request to take a host from, and a
  # phone needs an address it can reach. Until the address is set, the
  # current request's host.
  def phone_page_url(provider)
    options = AppSetting.current.url_options.to_h

    case provider
    when NoteProvider      then edit_note_url(provider, **options)
    when ChecklistProvider then edit_checklist_url(provider, **options)
    else raise ArgumentError, "#{provider.class} has no phone page"
    end
  end

  # A provider's phone page as a QR code, labeled for what it opens.
  def phone_page_qr_code(provider, module_px:)
    qr_code(phone_page_url(provider), module_px:,
            label: t("phone_pages.qr_code_label.#{provider.class.name.underscore}"))
  end

  # Black modules on white whatever the panel's theme, inside a quiet zone,
  # at a whole number of px per module so each lands on the pixel grid.
  def qr_code(text, module_px:, label:)
    qr     = RQRCode::QRCode.new(text, level: :m)
    offset = QR_QUIET_ZONE * module_px
    edge   = qr.modules.size * module_px + 2 * offset

    # rqrcode draws only rects and paths from the modules; the text is
    # encoded, never written into the markup.
    modules = qr.as_svg(module_size: module_px, offset:, color: "000", use_path: true, standalone: false).html_safe

    tag.svg(width: edge, height: edge, xmlns: "http://www.w3.org/2000/svg", "shape-rendering": "crispEdges",
            role: "img", aria: { label: }) do
      safe_join([ tag.rect(width: edge, height: edge, fill: "#fff"), modules ])
    end
  end
end
