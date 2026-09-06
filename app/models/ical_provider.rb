class IcalProvider < ApplicationRecord
  include Providable

  validates :ical_url, presence: true,
            format: { with: %r{\A(https?|webcal)://\S+\z} }
end
