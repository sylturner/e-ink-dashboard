module DashboardsHelper
  # The builder's single-click alternatives to dragging (WCAG 2.5.7), in
  # two groups of [label, resize?, [[button label, dx, dy], ...]].
  # grid_controller#moveBy applies them as the arrow keys do.
  BUILDER_MOVERS = [
    [ "Move", false, [ [ "Move left", -1, 0 ], [ "Move right", 1, 0 ], [ "Move up", 0, -1 ], [ "Move down", 0, 1 ] ] ],
    [ "Resize", true, [ [ "Narrower", -1, 0 ], [ "Wider", 1, 0 ], [ "Shorter", 0, -1 ], [ "Taller", 0, 1 ] ] ]
  ].freeze

  # Choices for a component select, labeled from the registry.
  def component_options
    Component::KINDS.map { [ Component.label(it), it ] }
  end

  # A builder tile's heading: its custom header, or the component's name.
  def builder_tile_title(item)
    item.title.presence || Component.label(item.kind)
  end

  # How screen readers name a tile: its heading, then the component and
  # layout, without repeating the component when it is the heading.
  def builder_tile_name(item)
    [ builder_tile_title(item), Component.label(item.kind), Component.views(item.kind)[item.view] ]
      .compact_blank.uniq.join(", ")
  end

  # The tile's accessible label, including where it sits on the grid.
  # grid_controller#describe rebuilds it in JS after a move: keep the two
  # formats in step.
  def builder_tile_label(item)
    "#{builder_tile_name(item)}, column #{item.col}, row #{item.row}, #{item.col_span} by #{item.row_span}"
  end

  # The text alternative for a dashboard's thumbnail: the tiles its
  # render shows, by heading.
  def dashboard_thumbnail_alt(dashboard)
    titles = dashboard.dashboard_items.select(&:visible?).map { builder_tile_title(it) }
    titles.any? ? "Preview showing #{titles.to_sentence}" : "Preview of an empty dashboard"
  end
end
