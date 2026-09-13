import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "tile", "preview", "status", "mover"]
  static values = { cols: Number, rows: Number }

  connect() {
    this.drag = null
    this.selected = null
    this.layout()

    this.onResize = () => this.layout()
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    clearTimeout(this.previewTimer)
  }

  // --- geometry -----------------------------------------------------

  // Reads the gap from the live CSS variable so render.css stays the
  // single source of truth for grid metrics.
  get metrics() {
    const styles = getComputedStyle(this.canvasTarget)
    const gap = parseFloat(styles.getPropertyValue("--grid-gap")) || 8
    const w = this.canvasTarget.clientWidth
    const h = this.canvasTarget.clientHeight

    return {
      gap,
      stepX: (w - (this.colsValue - 1) * gap) / this.colsValue + gap,
      stepY: (h - (this.rowsValue - 1) * gap) / this.rowsValue + gap,
      trackW: (w - (this.colsValue - 1) * gap) / this.colsValue,
      trackH: (h - (this.rowsValue - 1) * gap) / this.rowsValue
    }
  }

  coordsOf(tile) {
    return {
      col: parseInt(tile.dataset.col, 10),
      row: parseInt(tile.dataset.row, 10),
      colSpan: parseInt(tile.dataset.colSpan, 10),
      rowSpan: parseInt(tile.dataset.rowSpan, 10)
    }
  }

  place(tile, c) {
    const m = this.metrics
    tile.style.left = `${(c.col - 1) * m.stepX}px`
    tile.style.top = `${(c.row - 1) * m.stepY}px`
    tile.style.width = `${c.colSpan * m.trackW + (c.colSpan - 1) * m.gap}px`
    tile.style.height = `${c.rowSpan * m.trackH + (c.rowSpan - 1) * m.gap}px`
  }

  layout() {
    this.tileTargets.forEach((t) => this.place(t, this.coordsOf(t)))
  }

  // --- collision ----------------------------------------------------

  overlaps(a, b) {
    return a.col < b.col + b.colSpan &&
           b.col < a.col + a.colSpan &&
           a.row < b.row + b.rowSpan &&
           b.row < a.row + a.rowSpan
  }

  isFree(rect, exceptTile) {
    return this.tileTargets.every((t) =>
      t === exceptTile || !this.overlaps(rect, this.coordsOf(t))
    )
  }

  clamp(rect) {
    rect.colSpan = Math.max(1, Math.min(rect.colSpan, this.colsValue))
    rect.rowSpan = Math.max(1, Math.min(rect.rowSpan, this.rowsValue))
    rect.col = Math.max(1, Math.min(rect.col, this.colsValue - rect.colSpan + 1))
    rect.row = Math.max(1, Math.min(rect.row, this.rowsValue - rect.rowSpan + 1))
    return rect
  }

  // --- pointer ------------------------------------------------------

  start(event) {
    if (event.button !== 0) return

    const tile = event.currentTarget
    const mode = event.target.dataset.handle ? "resize" : "move"

    this.select(tile)

    this.drag = {
      tile,
      mode,
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      origin: this.coordsOf(tile),
      next: null
    }

    tile.classList.add("tile--active")
    event.preventDefault()
  }

  move(event) {
    if (!this.drag || event.pointerId !== this.drag.pointerId) return

    const m = this.metrics
    const dx = Math.round((event.clientX - this.drag.startX) / m.stepX)
    const dy = Math.round((event.clientY - this.drag.startY) / m.stepY)
    const o = this.drag.origin

    let next
    if (this.drag.mode === "resize") {
      next = { col: o.col, row: o.row,
               colSpan: o.colSpan + dx, rowSpan: o.rowSpan + dy }
    } else {
      next = { col: o.col + dx, row: o.row + dy,
               colSpan: o.colSpan, rowSpan: o.rowSpan }
    }

    next = this.clamp(next)
    this.drag.next = next

    this.place(this.drag.tile, next)
    this.drag.tile.classList.toggle(
      "tile--blocked", !this.isFree(next, this.drag.tile)
    )
  }

  end() {
    if (!this.drag) return

    const { tile, origin, next } = this.drag
    tile.classList.remove("tile--active", "tile--blocked")
    this.drag = null

    if (!next || !this.isFree(next, tile)) {
      this.place(tile, origin)
      return
    }

    const unchanged = next.col === origin.col && next.row === origin.row &&
                      next.colSpan === origin.colSpan &&
                      next.rowSpan === origin.rowSpan
    if (unchanged) return

    this.commit(tile, next, origin)
  }

  // Single-click buttons for the same one-step moves, so a tile can be
  // moved and resized without dragging (WCAG 2.5.7).
  moveBy({ params: { dx, dy, resize } }) {
    if (!this.selected || this.drag) return

    this.shift(dx, dy, resize)
  }

  // --- keyboard -----------------------------------------------------

  // Enter or Space on a focused tile selects it, the keyboard
  // counterpart of pressing it with a pointer. The view binds it with
  // Stimulus key filters: keydown.enter->grid#pick:prevent.
  pick({ currentTarget }) {
    this.select(currentTarget)
  }

  nudge(event) {
    if (this.drag) return
    if (!event.key.startsWith("Arrow")) return
    if (event.target.matches("input, textarea, select")) return

    // Arrow keys act on the tile that has focus, so they never move a
    // tile selected earlier that the keyboard user has since left.
    const focused = this.tileTargets.find((t) => t === event.target)
    if (focused && focused !== this.selected) this.select(focused)
    if (!this.selected) return

    const step = { ArrowLeft: [-1, 0], ArrowRight: [1, 0],
                   ArrowUp: [0, -1], ArrowDown: [0, 1] }[event.key]
    if (!step) return

    event.preventDefault()
    this.shift(step[0], step[1], event.shiftKey)
  }

  // Moves (or with `resize`, grows or shrinks) the selected tile by one
  // grid step, if the space is free.
  shift(dx, dy, resize) {
    const o = this.coordsOf(this.selected)

    let next = resize
      ? { ...o, colSpan: o.colSpan + dx, rowSpan: o.rowSpan + dy }
      : { ...o, col: o.col + dx, row: o.row + dy }

    next = this.clamp(next)
    if (!this.isFree(next, this.selected)) {
      this.status("That space is taken by another tile.")
      return
    }

    const unchanged = next.col === o.col && next.row === o.row &&
                      next.colSpan === o.colSpan && next.rowSpan === o.rowSpan
    if (unchanged) {
      this.status("The tile is already at the edge of the grid.")
      return
    }

    this.place(this.selected, next)
    this.commit(this.selected, next, o)
  }

  // --- persistence --------------------------------------------------

  async commit(tile, next, origin) {
    this.write(tile, next)
    this.status("Saving…")

    try {
      const response = await fetch(tile.dataset.repositionUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        body: JSON.stringify({
          dashboard_item: {
            col: next.col, row: next.row,
            col_span: next.colSpan, row_span: next.rowSpan
          }
        })
      })

      const body = await response.json()

      if (!response.ok || !body.ok) {
        throw new Error((body.errors || ["rejected"]).join(", "))
      }

      this.status(`Saved: ${tile.getAttribute("aria-label")}`)
      this.refreshPreview()
    } catch (error) {
      this.write(tile, origin)
      this.place(tile, origin)
      this.status(`Could not save: ${error.message}`)
    }
  }

  write(tile, c) {
    tile.dataset.col = c.col
    tile.dataset.row = c.row
    tile.dataset.colSpan = c.colSpan
    tile.dataset.rowSpan = c.rowSpan
    this.describe(tile)
  }

  // --- ui -----------------------------------------------------------

  select(tile) {
    this.tileTargets.forEach((t) => {
      t.classList.toggle("tile--selected", t === tile)
      t.setAttribute("aria-pressed", t === tile)
    })
    this.selected = tile
    this.moverTargets.forEach((button) => { button.disabled = false })

    // The view renders each tile's URLs from the routes, so none are
    // spelled out here.
    const frame = document.getElementById("inspector")
    if (frame) frame.src = tile.dataset.editUrl
  }

  // Keeps a tile's accessible name in step with where it sits. Mirrors
  // DashboardsHelper#builder_tile_label, which renders the first one.
  describe(tile) {
    const c = this.coordsOf(tile)
    tile.setAttribute("aria-label",
      `${tile.dataset.name}, column ${c.col}, row ${c.row}, ${c.colSpan} by ${c.rowSpan}`)
  }

  // Submits the enclosing form without an inline onchange handler, so
  // the page keeps working under a strict CSP.
  submit(event) {
    event.target.form?.requestSubmit()
  }

  status(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  refreshPreview() {
    if (!this.hasPreviewTarget) return

    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => {
      this.previewTarget.contentWindow.location.reload()
    }, 400)
  }
}
