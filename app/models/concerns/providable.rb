module Providable
  extend ActiveSupport::Concern

  included do
    has_one :source, as: :providable, touch: true
  end

  def fetch!
    raise NotImplementedError
  end
end
