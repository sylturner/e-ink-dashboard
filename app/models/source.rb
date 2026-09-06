class Source < ApplicationRecord
  # Discovered from app/models/providers rather than listed here. Adding
  # a provider is adding a file; each one declares its own label, form
  # attributes and refresh interval via Providable.provides.
  PROVIDERS = Providable.provider_names

  delegated_type :providable, types: PROVIDERS, dependent: :destroy

  has_many :dashboard_item_sources, dependent: :destroy
  has_many :dashboard_items, through: :dashboard_item_sources

  validates :name, presence: true
  validates :refresh_seconds,
            numericality: { greater_than_or_equal_to: 60 }

  scope :due, lambda {
    where(fetched_at: nil).or(
      where(arel_table[:fetched_at].lt(Arel.sql(
        "datetime('now', '-' || refresh_seconds || ' seconds')"
      )))
    )
  }

  # No constantize on user input: a type is only resolved if it matches a
  # name the registry found on disk, and the lookup itself never touches
  # a parameter. Returns nil for anything unknown.
  def self.provider_class(type)
    provider_classes[type.to_s]
  end

  def self.provider_classes
    @provider_classes ||= PROVIDERS.index_with { |name| Object.const_get(name) }.freeze
  end

  def self.provider_label(type)
    provider_class(type)&.label || type
  end

  def kind_label
    Source.provider_label(providable_type)
  end

  def healthy?
    fetched_at.present? && failure_count.to_i.zero?
  end

  def stale?
    return true if fetched_at.nil?

    fetched_at < (refresh_seconds * 2).seconds.ago
  end

  def in_use?
    dashboard_items.any?
  end

  def record_success(data)
    update!(payload: data, fetched_at: Time.current,
            attempted_at: Time.current, last_error: nil, failure_count: 0)
  end

  def record_failure(error)
    update!(attempted_at: Time.current,
            last_error: error.message.truncate(500),
            failure_count: failure_count.to_i + 1)
  end

  def tag
    name.to_s.first(3).upcase
  end
end
