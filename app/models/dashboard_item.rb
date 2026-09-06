class DashboardItem < ApplicationRecord
  KINDS = %w[clock calendar weather news text].freeze

  belongs_to :dashboard
  has_many :dashboard_item_sources,
           -> { order(:position) }, dependent: :destroy
  has_many :sources, through: :dashboard_item_sources

  validates :kind, inclusion: { in: KINDS }
  validates :col, :row, :col_span, :row_span,
            numericality: { greater_than: 0 }

  validate :fits_within_grid

  store_accessor :settings,
                 :day_count, :event_limit, :show_icons,
                 :text_size, :density

  scope :visible, -> { where(visible: true) }

  def grid_style
    "grid-column: #{col} / span #{col_span}; " \
    "grid-row: #{row} / span #{row_span};"
  end

  private

  def fits_within_grid
    return if dashboard.blank?

    if col + col_span - 1 > dashboard.grid_columns
      errors.add(:col_span, "extends past the grid")
    end
    if row + row_span - 1 > dashboard.grid_rows
      errors.add(:row_span, "extends past the grid")
    end
  end
end
