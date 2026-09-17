class DashboardItem < ApplicationRecord
  KINDS = Component::KINDS

  # What the tile inspector edits, for saving and for previewing. Position
  # and placement are owned by the builder, not by these forms.
  #
  # settings is an arbitrary hash, nested for a layout's parts and sizes:
  # the keys are whatever the registry rendered and the values only ever
  # reach ERB. Do not extend that to anything that reaches SQL or send.
  FORM_ATTRIBUTES = [ :dashboard_id, :kind, :view, :title, :col_span, :row_span, :visible,
                      { source_ids: [], settings: {} } ].freeze

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

  # Whether a layout draws one of its parts (Component::Part). Each layout
  # keeps its own choices under settings["parts"][view], so switching
  # layouts and back restores them.
  def shows?(key, view: self.view)
    Component.part!(kind, view, key).shown?(stored("parts", view, key))
  end

  # The size a part is drawn at, by name (small, medium, large).
  def size_name(key, view: self.view)
    Component.part!(kind, view, key).size_name(stored("sizes", view, key))
  end

  # What the partial draws at that size: an icon's px, a type class.
  def size_of(key)
    Component.part!(kind, view, key).size(size_name(key))
  end

  # How a news tile draws its headlines. A tile saved before it had one
  # draws the app's.
  def news_template
    NewsTemplate.from(settings["template"].presence || AppSetting.current.news_template.to_h)
  end

  # An unsaved copy with the inspector's changes, for the builder's
  # preview. It shares this tile's id and dashboard, and assigning sources
  # to a new record stays in memory, so nothing is written.
  def draft(attributes, dashboard: self.dashboard)
    self.class.new(self.attributes).tap do |copy|
      copy.dashboard = dashboard
      copy.source_ids = source_ids unless attributes.key?(:source_ids)
      copy.assign_attributes(attributes)
    end
  end

  def grid_style
    "grid-column: #{col} / span #{col_span}; " \
    "grid-row: #{row} / span #{row_span};"
  end

  private

    def apply_defaults
      self.view = Component.default_view(kind) if view.blank? && kind.present?
      self.settings = settings.merge("template" => news_template.to_h) if templated?
    end

    # A new tile starts with the app's template, and a saved one is kept in
    # the shape NewsTemplate reads, whatever the form sent.
    def templated?
      Component.templates(kind).any?
    end

    # settings[group][view][key], or nil. The nested hashes arrive
    # straight from the form, so don't trust their shape.
    def stored(group, view, key)
      [ group, view.to_s, key.to_s ].reduce(settings) { |node, name| node[name] if node.is_a?(Hash) }
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
