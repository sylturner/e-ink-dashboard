import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// A Markdown textarea with a toolbar that types the Markdown for you, as
// GitHub's does (application/_markdown_editor). What's saved is the
// text as written.
//
// Images are uploaded as they're pasted, dropped or chosen, through
// Active Storage's direct uploads, and go in as ![name](blob path).
// MarkdownHelper draws that blob on the panel.
const FORMATS = {
  bold:     { wrap: "**" },
  italic:   { wrap: "_" },
  strike:   { wrap: "~~" },
  code:     { wrap: "`", block: "```" },
  link:     { link: true },
  heading:  { line: "### " },
  quote:    { line: "> " },
  bullet:   { line: "- " },
  numbered: { line: "1. ", numbered: true },
  task:     { line: "- [ ] " }
}

export default class extends Controller {
  static targets = ["input", "file", "status"]
  static values = {
    uploadUrl: String,
    maxBytes: Number,
    uploading: String,
    uploaded: String,
    failed: String,
    notImage: String,
    tooBig: String
  }

  // A toolbar button: data-markdown-editor-format-param names the format.
  format({ params: { format } }) {
    this.apply(format)
  }

  // Keyboard shortcuts, from the textarea's keydown filters.
  bold()   { this.apply("bold") }
  italic() { this.apply("italic") }
  link()   { this.apply("link") }

  // The font and size menus: wrap the selection in a type marker
  // (MarkdownHelper). The font picker goes back to its heading itself.
  font({ target }) {
    if (target.value) this.mark(`{font:${target.value}}`, "{/font}")
  }

  size({ target }) {
    if (target.value) this.mark(`{size:${target.value}}`, "{/size}")
    target.value = ""
  }

  mark(open, close) {
    const { selectionStart: start, selectionEnd: end, value } = this.inputTarget
    const selected = value.slice(start, end)

    this.replace(start, end, `${open}${selected}${close}`, start + open.length, end + open.length)
  }

  choose() {
    this.fileTarget.click()
  }

  chosen() {
    this.upload([ ...this.fileTarget.files ])
    this.fileTarget.value = ""
  }

  paste(event) {
    const files = [ ...(event.clipboardData?.files || []) ]
    if (files.length === 0) return

    event.preventDefault()
    this.upload(files)
  }

  // Lets files be dropped: a drop is only allowed where dragover was
  // cancelled.
  dragover(event) {
    if (event.dataTransfer?.types.includes("Files")) event.preventDefault()
  }

  drop(event) {
    const files = [ ...(event.dataTransfer?.files || []) ]
    if (files.length === 0) return

    event.preventDefault()
    this.upload(files)
  }

  // --- Formatting ---

  apply(name) {
    const format = FORMATS[name]
    if (!format) return

    if (format.line) this.prefixLines(format)
    else if (format.link) this.wrapLink()
    else this.wrap(format)
  }

  // Wraps the selection (or places the cursor between the marks), or
  // unwraps it if it's already wrapped. A multi-line selection of code
  // becomes a fenced block.
  wrap({ wrap, block }) {
    const { selectionStart: start, selectionEnd: end, value } = this.inputTarget
    const selected = value.slice(start, end)

    if (block && selected.includes("\n")) {
      const fence = `${block}\n${selected}\n${block}`
      return this.replace(start, end, fence, start + block.length + 1, start + block.length + 1 + selected.length)
    }

    const before = value.slice(start - wrap.length, start)
    const after  = value.slice(end, end + wrap.length)
    if (before === wrap && after === wrap) {
      return this.replace(start - wrap.length, end + wrap.length, selected,
                          start - wrap.length, end - wrap.length)
    }

    this.replace(start, end, `${wrap}${selected}${wrap}`, start + wrap.length, end + wrap.length)
  }

  // [selection](url), with "url" selected to type over.
  wrapLink() {
    const { selectionStart: start, selectionEnd: end, value } = this.inputTarget
    const text = value.slice(start, end) || "text"
    const link = `[${text}](url)`
    const url  = start + text.length + 3

    this.replace(start, end, link, url, url + 3)
  }

  // Starts every selected line with the prefix, or takes it off if they
  // all have it already.
  prefixLines({ line, numbered }) {
    const { selectionStart: start, selectionEnd: end, value } = this.inputTarget
    const from = value.lastIndexOf("\n", start - 1) + 1
    const next = value.indexOf("\n", end)
    const to   = next === -1 ? value.length : next
    const lines = value.slice(from, to).split("\n")

    const pattern = numbered ? /^\d+\. / : new RegExp(`^${line.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`)
    const text = lines.every((text) => pattern.test(text))
      ? lines.map((text) => text.replace(pattern, "")).join("\n")
      : lines.map((text, index) => `${numbered ? `${index + 1}. ` : line}${text}`).join("\n")

    this.replace(from, to, text, from, from + text.length)
  }

  // Replaces a range as if typed, so the browser's undo still works, and
  // selects [selectFrom, selectTo] afterward.
  replace(start, end, text, selectFrom, selectTo) {
    const input = this.inputTarget
    input.focus()
    input.setSelectionRange(start, end)

    if (!document.execCommand("insertText", false, text)) {
      input.setRangeText(text, start, end, "end")
      this.changed()
    }
    input.setSelectionRange(selectFrom, selectTo)
  }

  // Tells the form (and the builder's preview) the text changed.
  changed() {
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // --- Images ---

  upload(files) {
    files.forEach((file) => {
      if (!file.type.startsWith("image/")) return this.announce(this.notImageValue, file)
      if (this.maxBytesValue && file.size > this.maxBytesValue) return this.announce(this.tooBigValue, file)

      const placeholder = `![${this.uploadingValue.replace("%{name}", file.name)}]()`
      this.insertOnOwnLine(placeholder)
      this.announce(this.uploadingValue, file)

      new DirectUpload(file, this.uploadUrlValue).create((error, blob) => {
        if (error) {
          this.swap(placeholder, "")
          return this.announce(this.failedValue, file)
        }

        const path = `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}`
        this.swap(placeholder, `![${this.altText(file.name)}](${path})`)
        this.announce(this.uploadedValue, file)
      })
    })
  }

  // Inserts at the cursor, on a line of its own.
  insertOnOwnLine(text) {
    const { selectionStart: start, selectionEnd: end, value } = this.inputTarget
    const before = start > 0 && value[start - 1] !== "\n" ? "\n" : ""
    const after  = value[end] === "\n" || end === value.length ? "" : "\n"
    const at = start + before.length + text.length + after.length

    this.replace(start, end, `${before}${text}${after}`, at, at)
  }

  // Replaces a placeholder wherever it has moved to while uploading,
  // leaving the cursor where the writer has it.
  swap(placeholder, text) {
    const input = this.inputTarget
    const at = input.value.indexOf(placeholder)
    if (at === -1) return

    input.setRangeText(text, at, at + placeholder.length, "preserve")
    this.changed()
  }

  // An image's alt text: its file name, without the extension or
  // anything that would end the Markdown early.
  altText(name) {
    return name.replace(/\.[^.]+$/, "").replace(/[[\]]/g, "")
  }

  announce(message, file) {
    this.statusTarget.textContent = message.replace("%{name}", file.name)
  }
}
