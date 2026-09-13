# Markup for the admin layout's sidebar and icons. Kept apart from
# IconHelper, which draws the panel's weather icons into the bitmap.
module NavigationHelper
  # The header's color-mode menu, as [mode, label, icon]. The mode names
  # are the ones theme_controller.js and the layout's inline script store.
  COLOR_MODES = [
    %w[light Light cil-sun],
    %w[dark Dark cil-moon],
    %w[auto Auto cil-contrast]
  ].freeze

  # A sidebar entry, highlighted while any of `controllers` is serving
  # the page, so the builder still counts as Dashboards.
  def sidebar_link(label, path, icon:, controllers:)
    active = controller_name.in?(Array(controllers))

    tag.li(class: "nav-item") do
      link_to path, class: class_names("nav-link", active:), aria: { current: ("page" if active) } do
        safe_join([ ui_icon(icon, classes: "nav-icon"), label ])
      end
    end
  end

  # An icon from the vendored CoreUI free sprite, by name ("cil-rss").
  def ui_icon(name, classes: "icon")
    tag.svg(class: classes, aria: { hidden: true }) do
      tag.use(href: "#{asset_path("coreui-icons-free.svg")}##{name}")
    end
  end
end
