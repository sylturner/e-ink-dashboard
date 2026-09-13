# Default form builder for the admin pages. It adds CoreUI/Bootstrap
# classes, so views write `f.text_field :name` and get a styled control
# that turns red when the attribute has an error. A class passed by the
# view is kept alongside the default rather than replacing it.
class AdminFormBuilder < ActionView::Helpers::FormBuilder
  CONTROL_FIELDS = %i[
    text_field email_field url_field number_field password_field search_field
    telephone_field phone_field date_field time_field datetime_field
    datetime_local_field month_field week_field file_field textarea
  ].freeze

  CONTROL_FIELDS.each do |helper|
    define_method(helper) do |method, options = {}|
      super(method, control_options(options, method, "form-control"))
    end
  end

  # Rails 8 renamed text_area and check_box to textarea and checkbox. The
  # old names are aliases of the parent's methods, so they have to be
  # pointed at these overrides too.
  alias_method :text_area, :textarea

  def color_field(method, options = {})
    super(method, control_options(options, method, "form-control form-control-color"))
  end

  def range_field(method, options = {})
    super(method, control_options(options, method, "form-range"))
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    super(method, choices, options, control_options(html_options, method, "form-select"), &block)
  end

  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    super(method, collection, value_method, text_method, options, control_options(html_options, method, "form-select"))
  end

  def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
    super(method, priority_zones, options, control_options(html_options, method, "form-select"))
  end

  def checkbox(method, options = {}, checked_value = "1", unchecked_value = "0")
    super(method, control_options(options, method, "form-check-input"), checked_value, unchecked_value)
  end
  alias_method :check_box, :checkbox

  def radio_button(method, tag_value, options = {})
    super(method, tag_value, control_options(options, method, "form-check-input"))
  end

  # `f.label :name, class: "x"` passes the options where the text goes.
  def label(method, text = nil, options = {}, &block)
    text, options = nil, text if text.is_a?(Hash)
    super(method, text, merge_class(options, "form-label"), &block)
  end

  def submit(value = nil, options = {})
    value, options = nil, value if value.is_a?(Hash)
    super(value, merge_class(options, "btn btn-primary"))
  end

  # Every error on the record, for the top of the form. Keeps the
  # `ul.errors` the existing forms and their tests already use.
  def error_messages
    return unless object.respond_to?(:errors) && object.errors.any?

    @template.tag.div(class: "alert alert-danger", role: "alert") do
      @template.tag.ul(class: "errors mb-0") do
        @template.safe_join(object.errors.full_messages.map { |message| @template.tag.li(message) })
      end
    end
  end

  # The errors for one attribute, shown under its `is-invalid` control.
  def invalid_feedback(method)
    return unless error?(method)

    @template.tag.div(object.errors.full_messages_for(method).to_sentence, class: "invalid-feedback")
  end

  private
    def control_options(options, method, base)
      merge_class(options, base, ("is-invalid" if error?(method)))
    end

    def merge_class(options, *classes)
      options.merge(class: @template.class_names(*classes, options[:class]))
    end

    def error?(method)
      object.respond_to?(:errors) && object.errors[method].any?
    end
end
