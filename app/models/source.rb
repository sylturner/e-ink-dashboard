class Source < ApplicationRecord
  PROVIDERS = %w[WeatherProvider RssProvider IcalProvider].freeze

  delegated_type :providable, types: PROVIDERS, dependent: :destroy

  has_many :dashboard_item_sources, dependent: :destroy
  has_many :dashboard_items, through: :dashboard_item_sources

  validates :name, presence: true

  scope :due, lambda {
    where(fetched_at: nil).or(
      where(arel_table[:fetched_at].lt(Arel.sql(
        "datetime('now', '-' || refresh_seconds || ' seconds')"
      )))
    )
  }

  def stale?
    fetched_at.nil? || fetched_at < (refresh_seconds * 2).seconds.ago
  end

  def record_success(data)
    update!(payload: data, fetched_at: Time.current,
            attempted_at: Time.current, last_error: nil, failure_count: 0)
  end

  def record_failure(error)
    update!(attempted_at: Time.current,
            last_error: error.message.truncate(500),
            failure_count: failure_count + 1)
  end
end
