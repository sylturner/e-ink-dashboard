# The Markdown editor's toolbar (application/_markdown_editor): each
# button's format (markdown_editor_controller.js's FORMATS), its CoreUI
# icon, and its keyboard shortcut, if it has one. Groups are separated in
# the toolbar.
module MarkdownEditorHelper
  BUTTONS = [
    [ [ "heading", "cil-header" ], [ "bold", "cil-bold", "B" ], [ "italic", "cil-italic", "I" ],
      [ "strike", "cil-strikethrough" ] ],
    [ [ "quote", "cil-double-quote-sans-left" ], [ "code", "cil-code" ], [ "link", "cil-link", "K" ] ],
    [ [ "bullet", "cil-list" ], [ "numbered", "cil-list-numbered" ], [ "task", "cil-task" ] ]
  ].freeze

  # A toolbar button that applies a format.
  def markdown_editor_button(format, icon, key = nil)
    label = t("markdown_editor.buttons.#{format}")
    title = key ? t("markdown_editor.shortcut", label:, key:) : label

    tag.button(ui_icon(icon), type: "button", class: "btn btn-sm btn-app-outline", title:,
               aria: { label:, keyshortcuts: ("Control+#{key} Meta+#{key}" if key) },
               data: { action: "markdown-editor#format", markdown_editor_format_param: format })
  end

  # The textarea's keydown filters for the shortcuts, on Control and on
  # Command.
  def markdown_editor_shortcuts
    BUTTONS.flatten(1).filter_map do |format, _, key|
      next unless key

      %w[ctrl meta].map { "keydown.#{it}+#{key.downcase}->markdown-editor##{format}:prevent" }
    end.flatten.join(" ")
  end
end
