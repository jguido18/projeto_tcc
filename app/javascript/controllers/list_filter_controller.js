import { Controller } from "@hotwired/stimulus"

// Filtra uma lista enquanto se digita — cada item declara o texto pesquisável
// em data-filter-text (ex.: nome + CPF).
export default class extends Controller {
  static targets = ["input", "item", "empty"]

  filter() {
    const query = this.normalize(this.inputTarget.value)
    let visible = 0

    this.itemTargets.forEach((item) => {
      const match = this.normalize(item.dataset.filterText).includes(query)
      item.hidden = !match
      if (match) visible += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
  }

  normalize(text) {
    return (text || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
  }
}
