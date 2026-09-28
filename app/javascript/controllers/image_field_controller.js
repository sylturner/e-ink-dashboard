import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// A tile's photo (dashboard_items/_image_field). A chosen picture is
// uploaded at once through Active Storage's direct uploads, and its
// blob's signed id goes in the hidden field the form saves, which the
// builder's preview picks up.
export default class extends Controller {
  static targets = ["value", "file", "preview", "image", "remove", "status"]
  static values = {
    uploadUrl: String,
    maxBytes: Number,
    uploading: String,
    uploaded: String,
    failed: String,
    notImage: String,
    tooBig: String,
    removed: String
  }

  chosen() {
    const [ file ] = this.fileTarget.files
    if (!file) return
    if (!file.type.startsWith("image/")) return this.announce(this.notImageValue, file)
    if (this.maxBytesValue && file.size > this.maxBytesValue) return this.announce(this.tooBigValue, file)

    this.announce(this.uploadingValue, file)
    new DirectUpload(file, this.uploadUrlValue).create((error, blob) => {
      if (error) return this.announce(this.failedValue, file)

      this.show(URL.createObjectURL(file))
      this.set(blob.signed_id)
      this.announce(this.uploadedValue, file)
    })
  }

  remove() {
    this.set("")
    this.fileTarget.value = ""
    this.previewTarget.hidden = true
    this.removeTarget.hidden = true
    this.statusTarget.textContent = this.removedValue
    this.fileTarget.focus()
  }

  show(url) {
    if (this.imageTarget.src.startsWith("blob:")) URL.revokeObjectURL(this.imageTarget.src)
    this.imageTarget.src = url
    this.previewTarget.hidden = false
    this.removeTarget.hidden = false
  }

  // Tells the inspector the setting changed, so the preview redraws.
  set(value) {
    this.valueTarget.value = value
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  announce(message, file) {
    this.statusTarget.textContent = message.replace("%{name}", file.name)
  }
}
