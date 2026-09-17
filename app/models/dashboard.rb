class Dashboard < ApplicationRecord
  # Keep in sync with the [data-theme] blocks in render.css.
  THEMES = %w[default quiet night dense classic_mac classic_windows cde].freeze

  # What the builder's Dashboard card edits, for saving and for previewing.
  FORM_ATTRIBUTES = %i[name theme grid_columns grid_rows].freeze

  has_many :dashboard_items, -> { order(:position) }, dependent: :destroy
  has_many :device_dashboards, dependent: :destroy
  has_many :devices, through: :device_dashboards

  # Only so destroying a dashboard clears it off any panel showing it;
  # `devices` above is the assignment relationship.
  has_many :showing_devices, class_name: "Device", dependent: :nullify

  # Frames rendered from it, the newest of which is its thumbnail. They
  # belong to their panels, so they outlive the dashboard.
  has_many :frames, dependent: :nullify

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

  # Asks every panel assigned to this dashboard for a new frame. A frame
  # is only composed when one is due, so without this a tile change would
  # wait for the next scheduled render.
  def request_refresh!
    devices.update_all(refresh_requested_at: Time.current)
  end

  def sources
    Source.joins(dashboard_item_sources: :dashboard_item)
          .where(dashboard_items: { dashboard_id: id })
          .distinct
  end
end
