import { Controller } from "@hotwired/stimulus"

// Derives the triage_validation[decision] field automatically:
//   - same level as AI suggestion  → "confirmed"
//   - different level              → "adjusted"
export default class extends Controller {
  static targets = ["decision"]
  static values = { originalLevel: String }

  connect() {
    // Read the AI-suggested level from the pre-selected radio
    const checked = this.element.querySelector("input[type='radio']:checked")
    this.originalLevelValue = checked?.value || ""
  }

  onUrgencyChange(event) {
    const selected = event.target.value
    const decision = selected === this.originalLevelValue ? "confirmed" : "adjusted"
    if (this.hasDecisionTarget) {
      this.decisionTarget.value = decision
    }
  }
}
