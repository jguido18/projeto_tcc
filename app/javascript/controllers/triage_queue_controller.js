import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = [
    "queueScreen", "callScreen",
    "ticketNumber", "urgencyCircle", "urgencyLabel",
    "position", "awaitingValidation", "boardBody"
  ]
  static values = { sessionId: Number, status: String }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "QueueChannel", session_id: this.sessionIdValue },
      { received: (data) => this.handleIncoming(data) }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  handleIncoming(data) {
    switch (data.type) {
      case "queued":
        this.showQueueInfo(data)
        break
      case "position_update":
        this.updatePosition(data.position)
        break
      case "called":
        this.showCallScreen(data.ticket_number)
        break
    }
  }

  showQueueInfo(data) {
    // Hide awaiting validation spinner
    if (this.hasAwaitingValidationTarget) {
      this.awaitingValidationTarget.style.display = "none"
    }

    // Show ticket info
    if (this.hasTicketNumberTarget) {
      this.ticketNumberTarget.textContent = data.ticket_number
    }

    if (this.hasUrgencyLabelTarget) {
      this.urgencyLabelTarget.textContent = data.urgency_label
      this.urgencyLabelTarget.className = `urgency-name urgency-name--${data.urgency_level}`
    }

    if (this.hasUrgencyCircleTarget) {
      this.urgencyCircleTarget.className = `urgency-circle urgency-circle--${data.urgency_level}`
    }

    if (this.hasPositionTarget) {
      this.positionTarget.textContent = `${data.position}º`
    }
  }

  updatePosition(position) {
    if (this.hasPositionTarget) {
      this.positionTarget.textContent = `${position}º`
    }
  }

  showCallScreen(ticketNumber) {
    if (this.hasQueueScreenTarget) {
      this.queueScreenTarget.style.display = "none"
    }
    if (this.hasCallScreenTarget) {
      this.callScreenTarget.style.display = "flex"
      // Flash the call screen green and play notification
      this.callScreenTarget.classList.add("call-screen--active")
      this.playNotificationSound()
    }
  }

  playNotificationSound() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)()
      const oscillator = ctx.createOscillator()
      const gain = ctx.createGain()
      oscillator.connect(gain)
      gain.connect(ctx.destination)
      oscillator.frequency.value = 880
      gain.gain.setValueAtTime(0.3, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5)
      oscillator.start(ctx.currentTime)
      oscillator.stop(ctx.currentTime + 0.5)
    } catch (_) {
      // Audio not available — silently ignore
    }
  }
}
