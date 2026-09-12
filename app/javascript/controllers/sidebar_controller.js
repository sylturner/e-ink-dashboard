import { Controller } from "@hotwired/stimulus"
import "@coreui/coreui"

// Drives CoreUI's Sidebar from the admin layout. CoreUI only sets up
// sidebars on window load, which Turbo visits never fire again, so the
// instance is created whenever a page's sidebar connects.
export default class extends Controller {
  static targets = [ "sidebar" ]

  sidebarTargetConnected(element) {
    window.coreui.Sidebar.getOrCreateInstance(element)
  }

  sidebarTargetDisconnected(element) {
    window.coreui.Sidebar.getInstance(element)?.dispose()
  }

  toggle() {
    window.coreui.Sidebar.getOrCreateInstance(this.sidebarTarget).toggle()
  }
}
