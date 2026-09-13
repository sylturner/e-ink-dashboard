import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view", "setting", "options"]

  connect() {
    this.viewChanged()
  }

  // Settings declare which layouts they apply to; hide the rest, and the
  // Options group itself when none are left.
  viewChanged() {
    const view = this.hasViewTarget ? this.viewTarget.value : null

    this.settingTargets.forEach((field) => {
      const views = (field.dataset.views || "").split(" ").filter(Boolean)
      const applies = views.length === 0 || views.includes(view)
      field.hidden = !applies
    })

    if (this.hasOptionsTarget) {
      this.optionsTarget.hidden = this.settingTargets.every((field) => field.hidden)
    }
  }

  // Kind determines which views and source types exist, so the server
  // has to rebuild the form.
  kindChanged(event) {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    const url = new URL(frame.src || window.location.href, window.location.origin)
    url.searchParams.set("kind", event.target.value)
    frame.src = url.toString()
  }
}
