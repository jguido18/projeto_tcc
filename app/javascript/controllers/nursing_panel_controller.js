import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["awaitingList", "queueList", "awaitingCount", "queueCount"]
  static values = { establishmentId: Number }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "NursingChannel" },
      { received: (data) => this.handleIncoming(data) }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  handleIncoming(data) {
    if (data.type === "panel_update") {
      this.reloadPanel()
    }
  }

  reloadPanel() {
    // Turbo will reload the panel frame; fallback: full page reload
    const frame = document.querySelector("turbo-frame#nursing-panel")
    if (frame) {
      frame.reload()
    } else {
      window.Turbo?.visit(window.location.href, { action: "replace" })
    }
  }
}
