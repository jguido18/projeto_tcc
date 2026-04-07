import { Controller } from "@hotwired/stimulus"

// Aplica máscaras de formatação em campos de texto.
// Uso: data-controller="mask" data-mask-type-value="cpf|phone"
export default class extends Controller {
  static values = { type: String }

  connect() {
    this.element.addEventListener("input", this.#apply.bind(this))
    this.element.addEventListener("keydown", this.#onKeydown.bind(this))
    // Aplica máscara se já houver valor (ex: edição de cadastro)
    if (this.element.value) this.#apply()
  }

  disconnect() {
    this.element.removeEventListener("input", this.#apply.bind(this))
    this.element.removeEventListener("keydown", this.#onKeydown.bind(this))
  }

  #onKeydown(e) {
    // Permite: backspace, delete, tab, escape, enter, arrows, ctrl/cmd+A/C/V/X
    const allowed = ["Backspace","Delete","Tab","Escape","Enter","ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"]
    if (allowed.includes(e.key)) return
    if ((e.ctrlKey || e.metaKey) && ["a","c","v","x"].includes(e.key.toLowerCase())) return
    // Bloqueia qualquer tecla que não seja número
    if (!/^\d$/.test(e.key)) e.preventDefault()
  }

  #apply() {
    const digits = this.element.value.replace(/\D/g, "")
    if (this.typeValue === "cpf") {
      this.element.value = this.#maskCpf(digits)
    } else if (this.typeValue === "phone") {
      this.element.value = this.#maskPhone(digits)
    }
  }

  #maskCpf(d) {
    if (d.length <= 3)  return d
    if (d.length <= 6)  return `${d.slice(0,3)}.${d.slice(3)}`
    if (d.length <= 9)  return `${d.slice(0,3)}.${d.slice(3,6)}.${d.slice(6)}`
    return `${d.slice(0,3)}.${d.slice(3,6)}.${d.slice(6,9)}-${d.slice(9,11)}`
  }

  #maskPhone(d) {
    if (d.length <= 2)  return d.length ? `(${d}` : d
    if (d.length <= 6)  return `(${d.slice(0,2)}) ${d.slice(2)}`
    if (d.length <= 10) return `(${d.slice(0,2)}) ${d.slice(2,6)}-${d.slice(6)}`
    return `(${d.slice(0,2)}) ${d.slice(2,7)}-${d.slice(7,11)}`
  }
}
