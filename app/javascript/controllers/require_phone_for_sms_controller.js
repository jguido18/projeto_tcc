import { Controller } from "@hotwired/stimulus"

// Torna o campo de telefone obrigatório enquanto o aviso por SMS estiver
// ativado — sem telefone não há para onde mandar a mensagem quando o
// paciente for chamado. O model (User#phone) valida a mesma regra no
// backend; isso aqui é só para o feedback imediato no formulário.
export default class extends Controller {
  static targets = ["checkbox", "phone"]

  connect() {
    this.sync()
  }

  sync() {
    this.phoneTarget.required = this.checkboxTarget.checked
  }
}
