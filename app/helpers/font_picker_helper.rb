# The font picker: a select whose choices each show their font
# (font_picker_controller.js, font_previews.css). It stays a real <select>
# underneath, so it submits, and works without JavaScript, like any other.
# Use it wherever someone picks a font family: AdminFormBuilder#font_select
# in a form, font_select_tag outside one.
module FontPickerHelper
  # Choices as [label, value, attributes], each naming the class that
  # previews its font. A choice that isn't a font (a blank, the ransom
  # letters) has none, and shows in the page's own type.
  def font_choices(choices = NewspaperFont.options)
    choices.map do |label, value|
      [ label, value, { data: { font_class: NewspaperFont.find(value)&.preview_class } } ]
    end
  end

  # The picker around any <select>. As a menu, its first choice is a
  # heading it returns to after each choice (the Markdown editor's toolbar).
  def font_picker(menu: false, &block)
    tag.div(class: "font-picker", data: { controller: "font-picker", font_picker_menu_value: (true if menu) }, &block)
  end

  def font_select_tag(name, choices = NewspaperFont.options, selected: nil, menu: false, **options)
    font_picker(menu:) do
      select_tag(name, options_for_select(font_choices(choices), selected),
                 **options.except(:class, :data), class: class_names("form-select", options[:class]),
                 data: { font_picker_target: "select", **options.fetch(:data, {}) })
    end
  end
end
