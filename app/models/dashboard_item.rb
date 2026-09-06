class DashboardItem < ApplicationRecord
  KINDS = Component::KINDS

  belongs_to :dashboard
  has_many :dashboard_item_sources,
           -> { order(:position) }, dependent: :destroy
  has_many :sources, through: :dashboard_item_sources

  before_validation :apply_defaults

  validates :kind, inclusion: { in: KINDS }
  validates :col, :row, :col_span, :row_span,
            numericality: { greater_than: 0 }

  validate :fits_within_grid
  validate :view_is_valid
  validate :sources_are_compatible

  scope :visible, -> { where(visible: true) }

  # Reads a setting through the registry, so a partial gets the declared
  # type and the declared default instead of a raw JSON string.
  def setting(key)
    definition = Component.setting(kind, key)
    return settings[key.to_s] if definition.nil?

    definition.cast(settings[key.to_s])
  end

  def grid_style
    "grid-column: #{col} / span #{col_span}; " \
    "grid-row: #{row} / span #{row_span};"
  end

  private

    def apply_defaults
      self.view = Component.default_view(kind) if view.blank? && kind.present?
    end

    def fits_within_grid
      return if dashboard.blank?

      if col + col_span - 1 > dashboard.grid_columns
        errors.add(:col_span, "extends past the grid")
      end
      if row + row_span - 1 > dashboard.grid_rows
        errors.add(:row_span, "extends past the grid")
      end
    end

    def view_is_valid
      return if kind.blank? || view.blank?
      return if Component.views(kind).key?(view)

      errors.add(:view, "isn't available for #{Component.label(kind)}")
    end

    def sources_are_compatible
      return if kind.blank?

      allowed = Component.source_types(kind)

      if allowed.empty?
        errors.add(:sources, "aren't used by #{Component.label(kind)}") if sources.any?
        return
      end

      bad = sources.reject { |s| allowed.include?(s.providable_type) }
      if bad.any?
        errors.add(:sources, "can't be used here: #{bad.map(&:name).to_sentence}")
      end

      if !Component.multi_source?(kind) && sources.size > 1
        errors.add(:sources, "only one is allowed for #{Component.label(kind)}")
      end
    end
end
