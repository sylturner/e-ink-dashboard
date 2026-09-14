# Shared behavior for the concrete providers behind a Source, plus the
# registry that discovers them.
#
# Everything a provider needs to describe itself -- its label, the
# attributes its form accepts, how often it should refresh -- is declared
# in the provider itself. Source has no per-provider knowledge.
module Providable
  extend ActiveSupport::Concern

  # One file per provider. The directory *is* the registry: drop in a new
  # provider and Source picks it up, with no list to keep in sync.
  DIRECTORY = "app/models/providers".freeze

  included do
    has_one :source, as: :providable, touch: true
  end

  # Class names, read off disk rather than by loading the classes, so
  # this is safe to call while Source itself is still being defined.
  def self.provider_names
    Rails.root.join(DIRECTORY).glob("*.rb")
         .map { |path| path.basename(".rb").to_s.camelize }
         .sort
  end

  class_methods do
    # Declares how this provider presents itself and what its form takes.
    # The label, icon (a name from the admin icon sprite, see
    # NavigationHelper#ui_icon) and description introduce it on the
    # add-a-source page.
    #
    # `polls: false` is for a provider whose data changes when it's edited
    # rather than on a schedule (NoteProvider): its source offers no
    # refresh interval and no Test button.
    def provides(label:, icon:, description:, attributes:, refresh_seconds:, polls: true)
      @label                   = label
      @icon                    = icon
      @description             = description
      @form_attributes         = attributes.map(&:to_sym).freeze
      @default_refresh_seconds = refresh_seconds
      @polls                   = polls
    end

    attr_reader :label, :icon, :description, :form_attributes, :default_refresh_seconds

    def polls?
      @polls != false
    end

    # Attributes a brand new record starts with. Overridden as a method
    # rather than declared in `provides` so anything zone- or
    # time-dependent is evaluated per call.
    def defaults
      {}
    end

    # Form params that aren't stored columns -- file uploads, or a
    # checkbox that clears something. Permitted alongside form_attributes
    # but exempt from the "every form attribute is a column" rule.
    def extra_params
      []
    end
  end

  def fetch!
    raise NotImplementedError
  end

  # One-line summary for the source list.
  def detail
    nil
  end
end
