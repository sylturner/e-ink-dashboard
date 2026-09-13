import { Controller } from "@hotwired/stimulus"

// Looks up a place by name and fills in a weather source's coordinates
// and time zone. Progress and outcomes go to a live region (the status
// target), so they are announced as well as shown.
export default class extends Controller {
  static targets = ["query", "status", "results", "latitude", "longitude", "timeZone"]
  static values = { url: String }

  async search() {
    const q = this.queryTarget.value.trim()
    if (!q) return

    this.resultsTarget.replaceChildren()
    this.announce("Searching…")

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", q)

      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const body = await response.json()
      if (body.error) throw new Error(body.error)

      if (!body.results.length) {
        this.announce(`No places match “${q}”.`)
        return
      }

      this.resultsTarget.replaceChildren(...body.results.map((place) => this.option(place)))
      const count = body.results.length
      this.announce(`${count} ${count === 1 ? "place" : "places"} found. Choose one below.`)
    } catch (error) {
      this.announce(`Lookup failed: ${error.message}`)
    }
  }

  // A button per place. Stimulus wires its action and params, so there
  // is no listener to attach or clean up.
  option(place) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "list-group-item list-group-item-action"
    button.textContent = place.label
    Object.assign(button.dataset, {
      action: "geocode#apply",
      geocodeLabelParam: place.label,
      geocodeLatitudeParam: place.latitude,
      geocodeLongitudeParam: place.longitude,
      geocodeTimeZoneParam: place.time_zone || ""
    })
    return button
  }

  apply({ params: { label, latitude, longitude, timeZone } }) {
    this.latitudeTarget.value = latitude
    this.longitudeTarget.value = longitude
    if (timeZone) this.timeZoneTarget.value = timeZone

    this.resultsTarget.replaceChildren()
    this.announce(`Using ${label}.`)
    // The button that had focus is gone; continue from the first field
    // it filled rather than dropping focus to the page.
    this.latitudeTarget.focus()
  }

  announce(message) {
    this.statusTarget.textContent = message
  }
}
