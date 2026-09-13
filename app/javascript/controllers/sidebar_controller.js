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

  // CoreUI 5.9's Sidebar adds a window resize listener that dispose()
  // leaves behind, and the listener's first call, _isMobile(), throws once
  // dispose has nulled the instance's properties. Every Turbo visit
  // replaces the sidebar, so after one a window resize would log a
  // TypeError. Stubbing that check after disposing (dispose would null a
  // stub set before it) lets the leftover listener return quietly.
  sidebarTargetDisconnected(element) {
    const sidebar = this.Sidebar.getInstance(element)
    if (!sidebar) return

    sidebar.dispose()
    sidebar._isMobile = () => false
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
