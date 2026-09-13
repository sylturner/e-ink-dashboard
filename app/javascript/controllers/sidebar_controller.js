import { Controller } from "@hotwired/stimulus"
import "@coreui/coreui"

// Drives CoreUI's Sidebar from the admin layout. CoreUI only sets up
// sidebars on window load, which Turbo visits never fire again, so the
// instance is created whenever a page's sidebar connects.
export default class extends Controller {
  static targets = [ "sidebar" ]

  sidebarTargetConnected(element) {
    this.Sidebar.getOrCreateInstance(element)
  }

  sidebarTargetDisconnected(element) {
    this.Sidebar.getInstance(element)?.dispose()
  }

  toggle() {
    this.Sidebar.getOrCreateInstance(this.sidebarTarget).toggle()
  }

  // The bundle is a UMD build: importing it defines window.coreui rather
  // than exporting the classes.
  get Sidebar() {
    return window.coreui.Sidebar
  }
}
