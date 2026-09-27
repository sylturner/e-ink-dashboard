import { Controller } from "@hotwired/stimulus"

// A font select that shows each font in itself (FontPickerHelper). The
// <select> stays in the form, hidden, and keeps the value: this draws a
// select-only combobox over it (the ARIA Authoring Practices pattern), since
// a native select's options can't be set in their own fonts everywhere.
// Choosing sets the select and fires its change and input events, so
// whatever listens to the select (the builder's preview, the Markdown
// editor) hears it.
//
// As a menu (data-font-picker-menu-value), the first choice is a heading,
// "Font", and the picker goes back to it once a choice is made: the
// Markdown editor's toolbar applies a font rather than keeping one.
let count = 0

export default class extends Controller {
  static targets = ["select"]
  static values = { menu: Boolean }

  connect() {
    const select = this.selectTarget
    const id = `${select.id || `font-picker-${++count}`}-picker`

    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.id = `${id}-button`
    this.button.className = `form-select font-picker-button ${select.className.replace("form-select", "")}`.trim()
    this.button.setAttribute("role", "combobox")
    this.button.setAttribute("aria-haspopup", "listbox")
    this.button.setAttribute("aria-expanded", "false")
    this.button.setAttribute("aria-controls", `${id}-list`)
    this.button.dataset.action = "font-picker#toggle keydown->font-picker#keydown blur->font-picker#close"
    for (const name of ["aria-label", "aria-describedby", "title"]) {
      if (select.hasAttribute(name)) this.button.setAttribute(name, select.getAttribute(name))
    }

    this.list = document.createElement("ul")
    this.list.id = `${id}-list`
    this.list.className = "font-picker-list"
    this.list.setAttribute("role", "listbox")
    this.list.setAttribute("tabindex", "-1")
    this.list.hidden = true

    this.options = [ ...select.options ].map((option, index) => {
      const item = document.createElement("li")
      item.id = `${id}-option-${index}`
      item.setAttribute("role", "option")
      item.textContent = option.textContent
      if (option.dataset.fontClass) item.classList.add(option.dataset.fontClass)
      // mousedown is held so the button keeps focus and stays open.
      item.dataset.action = "mousedown->font-picker#hold:prevent click->font-picker#pick"
      item.dataset.fontPickerIndexParam = index
      item.hidden = this.menuValue && index === 0
      this.list.append(item)
      return item
    })

    // A <label for> the select now names the button, which it can label.
    for (const label of select.labels) label.htmlFor = this.button.id
    if (select.labels.length > 0) this.button.removeAttribute("aria-label")

    select.hidden = true
    select.after(this.button, this.list)
    this.show()
  }

  disconnect() {
    for (const label of this.selectTarget.labels) label.htmlFor = this.selectTarget.id
    this.button?.remove()
    this.list?.remove()
    this.selectTarget.hidden = false
  }

  // --- Keyboard, as the pattern lays it out ---

  keydown(event) {
    const { key, altKey } = event
    const last = this.options.length - 1

    if (this.list.hidden) {
      if ([ "ArrowDown", "ArrowUp", "Enter", " " ].includes(key)) return this.handled(event, () => this.open())
      if (key === "Home") return this.handled(event, () => this.open(0))
      if (key === "End") return this.handled(event, () => this.open(last))
      if (this.printable(event)) return this.handled(event, () => { this.open(); this.typeahead(key) })
      return
    }

    switch (key) {
      case "ArrowDown": return this.handled(event, () => altKey ? this.close() : this.activate(this.active + 1))
      case "ArrowUp":   return this.handled(event, () => altKey ? this.chooseActive() : this.activate(this.active - 1))
      case "Home":      return this.handled(event, () => this.activate(0))
      case "End":       return this.handled(event, () => this.activate(last))
      case "PageDown":  return this.handled(event, () => this.activate(this.active + 10))
      case "PageUp":    return this.handled(event, () => this.activate(this.active - 10))
      case "Enter":
      case " ":         return this.handled(event, () => this.chooseActive())
      case "Escape":    return this.handled(event, () => this.close())
      case "Tab":       return this.chooseActive()
    }
    if (this.printable(event)) this.handled(event, () => this.typeahead(key))
  }

  handled(event, action) {
    event.preventDefault()
    action()
  }

  printable({ key, ctrlKey, metaKey, altKey }) {
    return key.length === 1 && key !== " " && !ctrlKey && !metaKey && !altKey
  }

  // Moves to the next choice starting with what's been typed in the last
  // half second.
  typeahead(key) {
    clearTimeout(this.typing)
    this.typed = `${this.typed || ""}${key.toLowerCase()}`
    this.typing = setTimeout(() => { this.typed = "" }, 500)

    const order = [ ...this.options.keys() ]
    const from = this.typed.length === 1 ? this.active + 1 : this.active
    const rotated = [ ...order.slice(from), ...order.slice(0, from) ]
    const match = rotated.find((index) => !this.options[index].hidden &&
                                          this.options[index].textContent.toLowerCase().startsWith(this.typed))
    if (match !== undefined) this.activate(match)
  }

  // --- Open, move, choose ---

  toggle() {
    this.list.hidden ? this.open() : this.close()
  }

  open(index = this.selectTarget.selectedIndex) {
    this.list.hidden = false
    this.button.setAttribute("aria-expanded", "true")
    this.activate(Math.max(index, 0))
  }

  close() {
    if (this.list.hidden) return

    this.list.hidden = true
    this.button.setAttribute("aria-expanded", "false")
    this.button.removeAttribute("aria-activedescendant")
  }

  activate(index) {
    const first = this.menuValue ? 1 : 0
    this.active = Math.min(Math.max(index, first), this.options.length - 1)
    this.options.forEach((item, at) => item.classList.toggle("active", at === this.active))

    const item = this.options[this.active]
    this.button.setAttribute("aria-activedescendant", item.id)
    item.scrollIntoView({ block: "nearest" })
  }

  hold() {}

  pick({ params: { index } }) {
    this.choose(index)
  }

  chooseActive() {
    this.choose(this.active)
  }

  choose(index) {
    const select = this.selectTarget
    const changed = select.selectedIndex !== index

    select.selectedIndex = index
    this.close()
    this.show()
    this.button.focus()

    if (changed) {
      select.dispatchEvent(new Event("input", { bubbles: true }))
      select.dispatchEvent(new Event("change", { bubbles: true }))
    }
    if (this.menuValue) {
      select.selectedIndex = 0
      this.show()
    }
  }

  // Draws the chosen font on the button, in itself, and marks it chosen
  // in the list. Also called by whoever sets the select's value directly.
  show() {
    const select = this.selectTarget
    const option = select.options[select.selectedIndex]

    this.button.textContent = option?.textContent || ""
    this.button.className = this.button.className.replace(/\s*font-preview--\S+/g, "")
    if (option?.dataset.fontClass) this.button.classList.add(option.dataset.fontClass)
    this.options.forEach((item, at) => item.setAttribute("aria-selected", String(at === select.selectedIndex)))
  }
}
