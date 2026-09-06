class WeatherProvider < ApplicationRecord
  include Providable

  validates :latitude, :longitude, presence: true
  validates :units, inclusion: { in: %w[imperial metric] }
end
