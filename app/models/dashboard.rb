class Dashboard < ApplicationRecord
  # Keep in sync with the [data-theme] blocks in render.css.
  THEMES = %w[default quiet night dense].freeze

  has_many :dashboard_items, -> { order(:position) }, dependent: :destroy
  has_many :device_dashboards, dependent: :destroy
  has_many :devices, through: :device_dashboards

  # Only so destroying a dashboard clears it off any panel showing it;
  # `devices` above is the assignment relationship.
  has_many :showing_devices, class_name: "Device", dependent: :nullify

  validates :name, presence: true
  validates :theme, inclusion: { in: THEMES }
  validates :grid_columns, :grid_rows,
            numericality: { greater_than: 0, less_than_or_equal_to: 24 }

  # The panel size the dashboard renders at: its first device's, or the
  # default panel's when none is assigned (the same fallback as
  # layouts/render.html.erb).
  def screen_size
    device = devices.first
    device ? [ device.width, device.height ] : Device.column_defaults.values_at("width", "height")
  end

  def sources
    Source.joins(dashboard_item_sources: :dashboard_item)
          .where(dashboard_items: { dashboard_id: id })
          .distinct
  end
end
