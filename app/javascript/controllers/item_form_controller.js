import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kind", "view", "setting", "group"]

  connect() {
    this.viewChanged()
  }

  // Settings, and each layout's group of parts, declare which layouts
  // they apply to; hide the rest, and any group left with nothing in it.
  viewChanged() {
    const view = this.hasViewTarget ? this.viewTarget.value : null

    this.settingTargets.forEach((field) => {
      const views = (field.dataset.views || "").split(" ").filter(Boolean)
      const applies = views.length === 0 || views.includes(view)
      field.hidden = !applies
    })

    this.groupTargets.forEach((group) => {
      const fields = this.settingTargets.filter((field) => group.contains(field))
      group.hidden = fields.every((field) => field.hidden)
    })
  }

  // Tells the builder (grid_controller) a field changed, so it can
  // preview the change. Not the component, which rebuilds the form.
  changed({ target }) {
    if (this.hasKindTarget && target === this.kindTarget) return

    this.dispatch("changed")
  }

  // Kind determines which views and source types exist, so the server
  // has to rebuild the form. The builder previews the rebuilt one.
  kindChanged(event) {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    this.dispatch("rebuilding")

    const url = new URL(frame.src || window.location.href, window.location.origin)
    url.searchParams.set("kind", event.target.value)
    frame.src = url.toString()
  }
}
