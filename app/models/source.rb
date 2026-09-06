class Source < ApplicationRecord
  PROVIDERS = %w[WeatherProvider RssProvider IcalProvider].freeze

  # Attributes each provider type accepts from a form.
  PROVIDER_ATTRIBUTES = {
    "WeatherProvider" => %i[latitude longitude units time_zone],
    "RssProvider"     => %i[feed_url max_items],
    "IcalProvider"    => %i[ical_url include_all_day]
  }.freeze

  PROVIDER_LABELS = {
    "WeatherProvider" => "Weather",
    "RssProvider"     => "RSS feed",
    "IcalProvider"    => "Calendar (iCal)"
  }.freeze

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

  # Resolved by an explicit case rather than constantize: the input is
  # allowlisted, but reflection on a param value is a real hazard and
  # this keeps it off the table entirely. Returns nil for anything not
  # in PROVIDERS.
  def self.provider_class(type)
    case type.to_s
    when "WeatherProvider" then WeatherProvider
    when "RssProvider"     then RssProvider
    when "IcalProvider"    then IcalProvider
    end
  end

  def kind_label
    PROVIDER_LABELS.fetch(providable_type, providable_type)
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
end
