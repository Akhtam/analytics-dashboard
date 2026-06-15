import { Controller } from "@hotwired/stimulus"

// Drives the live-feed simulator. When "live", it POSTs to the simulate endpoint
// on an interval; the server creates a call and broadcasts it back into the feed
// via Turbo Streams. Uses fetch (not a form) so it works even when nested inside
// the filter form. Starts paused.
export default class extends Controller {
  static targets = ["button"]
  static values = { url: String, interval: { type: Number, default: 4000 } }

  disconnect() {
    this.stop()
  }

  toggle() {
    this.live = !this.live
    this.live ? this.start() : this.stop()
    this.buttonTarget.textContent = this.live ? "⏸ Pause" : "▶ Go live"
  }

  start() {
    this.timer = setInterval(() => this.ping(), this.intervalValue)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }

  ping() {
    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": this.csrfToken },
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
