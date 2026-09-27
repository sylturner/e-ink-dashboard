import { Controller } from "@hotwired/stimulus"

// Keeps keyboard focus on a checklist's phone page (checklists/edit). Each
// button there is a form of its own that comes back to the page, which
// Turbo morphs in place. Turbo disables a button while its form is sent,
// and a disabled button loses focus, so this puts focus back on the button
// that was pressed (its data-focus-key), or, if that one's gone or can't be
// used now (a moved item at the top), on its item's toggle, then on the
// field that adds an item.
export default class extends Controller {
  static targets = ["fallback"]

  remember({ detail: { formSubmission } }) {
    const { submitter } = formSubmission
    this.key = this.element.contains(submitter) ? submitter?.dataset.focusKey : null
    this.item = submitter?.closest("[data-focus-item]")?.dataset.focusItem
  }

  restore() {
    if (!this.key) return

    const candidates = [
      `[data-focus-key="${this.key}"]`,
      this.item && `[data-focus-key="toggle-${this.item}"]`
    ].filter(Boolean)
    const target = candidates.map((selector) => this.element.querySelector(selector))
                             .find((element) => element && !element.disabled)

    ;(target || this.fallbackTarget).focus()
    this.key = null
  }
}
