require "test_helper"

class AdminFormBuilderTest < ActionView::TestCase
  setup do
    @dashboard = Dashboard.new
  end

  def render_form(&block)
    @rendered = form_with(model: @dashboard, url: "/dashboards", builder: AdminFormBuilder, &block)
  end

  test "text inputs get form-control and keep a class passed by the view" do
    render_form { |f| f.text_field :name, class: "w-50" }

    assert_select "input.form-control.w-50[name=?]", "dashboard[name]"
  end

  test "Rails 8 helper names and their older aliases are both styled" do
    render_form do |f|
      safe_join([ f.textarea(:name), f.text_area(:theme), f.phone_field(:name), f.telephone_field(:theme) ])
    end

    assert_select "textarea.form-control", 2
    assert_select "input[type=tel].form-control", 2
  end

  test "selects get form-select" do
    render_form do |f|
      safe_join([
        f.select(:theme, Dashboard::THEMES),
        f.collection_select(:grid_columns, [ 4, 8 ], :itself, :itself)
      ])
    end

    assert_select "select.form-select", 2
  end

  test "labels, checkboxes, radio buttons and submit buttons are styled" do
    render_form do |f|
      safe_join([ f.label(:name, class: "fw-bold"), f.checkbox(:name), f.check_box(:theme),
                  f.radio_button(:theme, "night"), f.submit ])
    end

    assert_select "label.form-label.fw-bold[for=?]", "dashboard_name"
    assert_select "input[type=checkbox].form-check-input", 2
    assert_select "input[type=radio].form-check-input"
    assert_select "input[type=submit].btn.btn-primary"
  end

  test "range and color inputs get their own control classes" do
    render_form { |f| safe_join([ f.range_field(:grid_columns), f.color_field(:name) ]) }

    assert_select "input[type=range].form-range"
    assert_select "input[type=color].form-control.form-control-color"
  end

  test "a field with an error is marked invalid and explains why" do
    @dashboard.errors.add(:name, :blank)

    render_form do |f|
      safe_join([ f.error_messages, f.text_field(:name), f.invalid_feedback(:name), f.text_field(:theme) ])
    end

    assert_select ".alert.alert-danger ul.errors li", "Name can't be blank"
    assert_select "input.form-control.is-invalid[name=?]", "dashboard[name]"
    assert_select ".invalid-feedback", "Name can't be blank"
    assert_select "input.is-invalid", 1
  end

  test "a valid record renders no error markup" do
    render_form do |f|
      safe_join([ f.error_messages, f.text_field(:name), f.invalid_feedback(:name) ].compact)
    end

    assert_select ".alert", 0
    assert_select ".is-invalid", 0
    assert_select ".invalid-feedback", 0
  end
end
