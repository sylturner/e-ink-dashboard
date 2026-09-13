class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # CoreUI classes on form controls; see app/form_builders.
  default_form_builder AdminFormBuilder

  # Times and weeks follow the app's settings, on the admin pages and in
  # everything the panels ask for.
  around_action { |_controller, action| AppSetting.current.apply(&action) }
end
