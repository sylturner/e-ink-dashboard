class Dashboard < ApplicationRecord
  has_many :dashboard_items, -> { order(:position) }, dependent: :destroy
  has_many :devices, dependent: :nullify

  validates :name, presence: true
  validates :grid_columns, :grid_rows,
            numericality: { greater_than: 0, less_than_or_equal_to: 24 }

  def sources
    Source.joins(dashboard_item_sources: :dashboard_item)
          .where(dashboard_items: { dashboard_id: id })
          .distinct
  end
end
