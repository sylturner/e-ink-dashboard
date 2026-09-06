class RssProvider < ApplicationRecord
  include Providable

  validates :feed_url, presence: true,
            format: { with: %r{\Ahttps?://\S+\z} }
end
