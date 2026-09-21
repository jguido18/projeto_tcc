import { Controller } from "@hotwired/stimulus"

// Mostra/oculta um campo associado a um checkbox (ex: data de validade de
// uma condição de prioridade temporária). Limpa o valor ao ocultar.
export default class extends Controller {
  static targets = ["checkbox", "field"]

  connect() {
    this.sync()
  }

  sync() {
    const checked = this.checkboxTarget.checked

    this.fieldTargets.forEach((field) => {
      field.hidden = !checked
      if (!checked) {
        const input = field.querySelector("input")
        if (input) input.value = ""
      }
    })
  }
}
