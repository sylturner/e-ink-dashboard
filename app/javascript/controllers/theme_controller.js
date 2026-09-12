import { Controller } from "@hotwired/stimulus"

// Light / dark / auto switch in the header. The layout's <head> applies
// the saved choice before first paint; this keeps it in step afterwards,
// including when the system setting changes while in auto.
const STORAGE_KEY = "color-mode"
const systemDark = window.matchMedia("(prefers-color-scheme: dark)")

export default class extends Controller {
  static targets = [ "option" ]

  connect() {
    this.follow = () => this.apply()
    systemDark.addEventListener("change", this.follow)
    this.apply()
  }

  disconnect() {
    systemDark.removeEventListener("change", this.follow)
  }

  pick({ params: { mode } }) {
    try { localStorage.setItem(STORAGE_KEY, mode) } catch {}
    this.apply()
  }

  apply() {
    const mode = this.mode
    const dark = mode === "dark" || (mode === "auto" && systemDark.matches)
    document.documentElement.setAttribute("data-coreui-theme", dark ? "dark" : "light")

    this.optionTargets.forEach(option => {
      const active = option.dataset.themeModeParam === mode
      option.classList.toggle("active", active)
      option.setAttribute("aria-pressed", active)
    })
  }

  get mode() {
    try { return localStorage.getItem(STORAGE_KEY) || "auto" } catch { return "auto" }
  }
}
