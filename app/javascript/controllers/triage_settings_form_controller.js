import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["levelsContainer", "levelTemplate", "levelRow"]

  addLevel() {
    const nextIndex = this.levelRowTargets.length
    const nextWeight = nextIndex + 1
    const html = this.levelTemplateTarget.innerHTML
      .replaceAll("__INDEX__", String(nextIndex))
      .replaceAll("__WEIGHT__", String(nextWeight))

    this.levelsContainerTarget.insertAdjacentHTML("beforeend", html)
  }

  removeLevel(event) {
    const row = event.currentTarget.closest("[data-triage-settings-form-target='levelRow']")
    if (!row) return

    row.remove()
    this.reindexRows()
  }

  reindexRows() {
    this.levelRowTargets.forEach((row, idx) => {
      const inputs = row.querySelectorAll("input")

      inputs.forEach((input) => {
        const name = input.getAttribute("name")
        if (!name) return

        input.setAttribute("name", name.replace(/\[\d+\]/, `[${idx}]`))
      })
    })
  }
}
