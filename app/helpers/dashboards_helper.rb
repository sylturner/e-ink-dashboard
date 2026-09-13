module DashboardsHelper
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
end
