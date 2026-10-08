import { Controller } from "@hotwired/stimulus"

// Card de check-in da TV da recepção: busca o código atual (que troca a cada
// minuto) e se atualiza sozinho logo depois de cada troca.
export default class extends Controller {
  static targets = ["qr", "code", "countdown"]
  static values = { url: String }

  connect() {
    this.refresh()
    this._tick = setInterval(() => this.updateCountdown(), 1000)
  }

  disconnect() {
    clearTimeout(this._nextRefresh)
    clearInterval(this._tick)
  }

  async refresh() {
    clearTimeout(this._nextRefresh)
    let retryInMs = 10_000

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (response.ok) {
        const data = await response.json()
        this.qrTarget.innerHTML = data.qr_svg
        this.codeTarget.textContent = data.code.replace(/(\d{3})(\d{3})/, "$1 $2")
        this.remaining = data.seconds_remaining
        this.updateCountdown()
        // Busca de novo logo após o código trocar no servidor
        retryInMs = (data.seconds_remaining + 1) * 1000
      }
    } catch {
      // Sem rede: tenta de novo em alguns segundos
    }

    this._nextRefresh = setTimeout(() => this.refresh(), retryInMs)
  }

  updateCountdown() {
    if (this.remaining === undefined) return
    this.countdownTarget.textContent = Math.max(this.remaining, 0)
    this.remaining -= 1
  }
}
