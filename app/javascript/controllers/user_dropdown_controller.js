import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("user-dropdown__menu--open")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("user-dropdown__menu--open")
    }
  }

  connect() {
    this._closeHandler = this.close.bind(this)
    document.addEventListener("click", this._closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._closeHandler)
  }
}
