import { Controller } from "@hotwired/stimulus"

// A headline template's fields (news_templates/_fields). Hides the ones
// the current choices don't use: a picture's size when there's no
// picture, a line's format unless it's custom, and a line's size and
// wrapping when it shows nothing. Hidden fields still save.
export default class extends Controller {
  static targets = ["placement", "imageSize", "field", "format", "style"]

  connect() {
    this.update()
  }

  update() {
    if (this.hasPlacementTarget && this.hasImageSizeTarget) {
      this.imageSizeTarget.hidden = this.placementTarget.value === "none"
    }

    // One field, format and style per line, in the same order.
    this.fieldTargets.forEach((field, index) => {
      this.formatTargets[index].hidden = field.value !== "custom"
      this.styleTargets[index].hidden = field.value === "none"
    })
  }
}
