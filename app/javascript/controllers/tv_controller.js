import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

const SPOTLIGHT_DURATION_MS = 8000  // tempo que o destaque fica na tela

export default class extends Controller {
  static targets = [
    "clock", "spotlight",
    "spotlightTicket", "spotlightName", "spotlightUrgency",
    "queueBody", "totalCount"
  ]
  static values = { establishmentId: Number }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "TvChannel", establishment_id: this.establishmentIdValue },
      { received: (data) => this.handleIncoming(data) }
    )
    this.startClock()
  }

  disconnect() {
    this.subscription?.unsubscribe()
    clearInterval(this._clockInterval)
    clearTimeout(this._spotlightTimeout)
  }

  // ── Mensagens recebidas via WebSocket ──────────────────────────────

  handleIncoming(data) {
    switch (data.type) {
      case "new_call":
        this.showSpotlight(data)
        break
      case "queue_update":
        this.updateQueue(data.entries)
        break
    }
  }

  // ── Destaque de chamada (spotlight) ───────────────────────────────

  showSpotlight(data) {
    this.spotlightTicketTarget.textContent  = data.ticket_number
    this.spotlightNameTarget.textContent    = data.patient_name
    this.spotlightUrgencyTarget.textContent = data.urgency_label
    this.spotlightUrgencyTarget.className   = `tv-spotlight__urgency urgency-bg--${data.urgency_level}`
    this.spotlightTarget.className          = `tv-spotlight tv-spotlight--${data.urgency_level} tv-spotlight--visible`

    this.playBeep()

    clearTimeout(this._spotlightTimeout)
    this._spotlightTimeout = setTimeout(() => {
      this.spotlightTarget.style.display = "none"
      this.spotlightTarget.className = "tv-spotlight"
    }, SPOTLIGHT_DURATION_MS)
  }

  // ── Atualização da tabela de fila ─────────────────────────────────

  updateQueue(entries) {
    this.totalCountTarget.textContent = entries.length

    if (entries.length === 0) {
      this.queueBodyTarget.innerHTML =
        `<tr class="tv-table__empty-row"><td colspan="4">${this._emptyText()}</td></tr>`
      return
    }

    this.queueBodyTarget.innerHTML = entries.map((e, idx) => `
      <tr class="tv-row tv-row--${e.urgency_level} ${idx === 0 ? "tv-row--first" : ""}">
        <td class="tv-row__ticket">${e.ticket_number}</td>
        <td class="tv-row__name">${e.patient_name}</td>
        <td><span class="urgency-badge urgency-bg--${e.urgency_level}">${e.urgency_label}</span></td>
        <td class="tv-row__time">${e.called_at || "—"}</td>
      </tr>
    `).join("")
  }

  // ── Relógio ───────────────────────────────────────────────────────

  startClock() {
    const tick = () => {
      if (this.hasClockTarget) {
        this.clockTarget.textContent = new Date().toLocaleTimeString("pt-BR", {
          hour: "2-digit", minute: "2-digit", second: "2-digit"
        })
      }
    }
    tick()
    this._clockInterval = setInterval(tick, 1000)
  }

  // ── Som de chamada ────────────────────────────────────────────────

  playBeep() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)()
      const beep = (freq, start, duration) => {
        const osc  = ctx.createOscillator()
        const gain = ctx.createGain()
        osc.connect(gain)
        gain.connect(ctx.destination)
        osc.frequency.value = freq
        gain.gain.setValueAtTime(0.4, ctx.currentTime + start)
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + start + duration)
        osc.start(ctx.currentTime + start)
        osc.stop(ctx.currentTime + start + duration)
      }
      beep(880, 0,    0.18)
      beep(880, 0.22, 0.18)
      beep(1100, 0.5, 0.4)
    } catch (_) { /* sem suporte a áudio */ }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  _emptyText() {
    return this.element.dataset.tvEmptyMessage || "Nenhuma chamada no momento."
  }
}
