module DashboardItemsHelper
  # A builder for one layout's part toggles or part sizes, whose fields
  # are named dashboard_item[settings][<group>][<view>][<key>]: the paths
  # DashboardItem#shows? and #size_of read. The settings hash is no
  # object to read values from, so each field passes its own.
  def part_fields(form, group, view)
    nested_fields(form, :settings, group, view)
  end

  # A line under a part in the inspector saying why it won't draw yet, or
  # nil when it will.
  def part_hint(item, part)
    case [ item.kind, part.key ]
    when [ "note", "qr_code" ]
      return if AppSetting.current.server_url?

      # The inspector sits in a turbo frame; Settings is a whole page.
      t("components.part_hints.note.qr_code_html",
        settings: link_to(t("notes.settings"), edit_settings_path, data: { turbo_frame: "_top" }))
    end
  end

  # Choices for a sized part's select.
  def part_size_options
    Component::SIZE_NAMES.map { [ t("components.sizes.#{it}"), it ] }
  end
end
