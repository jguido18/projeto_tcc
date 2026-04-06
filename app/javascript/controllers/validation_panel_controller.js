import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["awaitingList", "queueList", "awaitingCount", "queueCount"]

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "ValidationPanelChannel" },
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
    const frame = document.querySelector("turbo-frame#validation-panel")
    if (frame) {
      frame.reload()
    } else {
      window.Turbo?.visit(window.location.href, { action: "replace" })
    }
  }
}
