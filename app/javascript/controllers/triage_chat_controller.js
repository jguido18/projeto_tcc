import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "submitBtn", "inputArea", "status"]
  static values  = { sessionId: Number, messageUrl: String }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "TriageChannel", session_id: this.sessionIdValue },
      { received: (data) => this.handleIncoming(data) }
    )
    this.scrollToBottom()
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  sendMessage(event) {
    event.preventDefault()
    const content = this.inputTarget.value.trim()
    if (!content) return

    this.appendMessage("user", content)
    this.inputTarget.value = ""
    this.setLoading(true)

    fetch(this.messageUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ content })
    })
    .then(r => r.json())
    .then(data => {
      if (data.finished) {
        this.statusTarget.textContent = "Aguardando validação..."
        this.inputAreaTarget.style.display = "none"
        setTimeout(() => { window.location = data.redirect_to }, 1500)
      }
    })
    .catch(() => this.setLoading(false))
  }

  handleIncoming(data) {
    if (data.type === "message" && data.sender === "ai") {
      this.setLoading(false)
      this.appendMessage("ai", data.content)
    }
    if (data.type === "status_change") {
      this.statusTarget.textContent = "Aguardando validação..."
      this.inputAreaTarget.style.display = "none"
    }
  }

  appendMessage(sender, content) {
    const div = document.createElement("div")
    div.className = `message message--${sender}`
    div.innerHTML = `<div class="message-bubble">${this.escapeHtml(content)}</div>`
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  setLoading(loading) {
    this.submitBtnTarget.disabled = loading
    this.inputTarget.disabled = loading
    if (loading) {
      this.appendTypingIndicator()
    } else {
      this.removeTypingIndicator()
    }
  }

  appendTypingIndicator() {
    const div = document.createElement("div")
    div.className = "message message--ai typing-indicator"
    div.id = "typing-indicator"
    div.innerHTML = `<div class="message-bubble"><span></span><span></span><span></span></div>`
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  removeTypingIndicator() {
    document.getElementById("typing-indicator")?.remove()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  escapeHtml(str) {
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
              .replace(/\n/g, "<br>")
  }
}
