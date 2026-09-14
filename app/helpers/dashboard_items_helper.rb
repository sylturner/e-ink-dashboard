module DashboardItemsHelper
  # A builder for one layout's part toggles or part sizes, whose fields
  # are named dashboard_item[settings][<group>][<view>][<key>]: the paths
  # DashboardItem#shows? and #size_of read. The settings hash is no
  # object to read values from, so each field passes its own.
  def part_fields(form, group, view)
    form.class.new("#{form.object_name}[settings][#{group}][#{view}]", nil, self, form.options)
  end

  # Choices for a sized part's select.
  def part_size_options
    Component::SIZE_NAMES.map { [ t("components.sizes.#{it}"), it ] }
  end
end
