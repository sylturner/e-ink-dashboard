import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "latitude", "longitude", "timeZone"]

  async search(event) {
    event.preventDefault()

    const q = this.queryTarget.value.trim()
    if (!q) return

    this.resultsTarget.innerHTML = "<li>Searching…</li>"

    try {
      const response = await fetch(`/sources/geocode?q=${encodeURIComponent(q)}`, {
        headers: { Accept: "application/json" }
      })
      const body = await response.json()

      if (!body.results.length) {
        this.resultsTarget.innerHTML = "<li>No matches</li>"
        return
      }

      this.resultsTarget.innerHTML = ""
      body.results.forEach((place) => {
        const li = document.createElement("li")
        const button = document.createElement("button")
        button.type = "button"
        button.textContent = place.label
        button.addEventListener("click", () => this.apply(place))
        li.appendChild(button)
        this.resultsTarget.appendChild(li)
      })
    } catch (error) {
      this.resultsTarget.innerHTML = `<li>Lookup failed: ${error.message}</li>`
    }
  }

  apply(place) {
    this.latitudeTarget.value = place.latitude
    this.longitudeTarget.value = place.longitude
    if (place.time_zone) this.timeZoneTarget.value = place.time_zone
    this.resultsTarget.innerHTML = `<li>Using ${place.label}</li>`
  }
}
