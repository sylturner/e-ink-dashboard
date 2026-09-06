# Scans the grid for the first opening that fits, so a newly added item
# never lands on top of an existing one.
class FreeSlot
  def self.find(dashboard, col_span, row_span)
    occupied = Set.new

    dashboard.dashboard_items.each do |item|
      item.row.upto(item.row + item.row_span - 1) do |r|
        item.col.upto(item.col + item.col_span - 1) do |c|
          occupied << [ c, r ]
        end
      end
    end

    1.upto(dashboard.grid_rows - row_span + 1) do |row|
      1.upto(dashboard.grid_columns - col_span + 1) do |col|
        cells = (row...row + row_span).flat_map do |r|
          (col...col + col_span).map { |c| [ c, r ] }
        end
        return [ col, row ] if cells.none? { |cell| occupied.include?(cell) }
      end
    end

    nil
  end
end
