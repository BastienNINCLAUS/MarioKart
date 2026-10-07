import { Controller } from "@hotwired/stimulus"

// Turbo ignore un rechargement reçu pendant qu'une visite est en cours : la page pourrait rester périmée après
// une rafale de diffusions. On redemande donc un rechargement un peu après la dernière.
export default class extends Controller {
  static values = { delay: { type: Number, default: 800 } }

  connect() {
    this.onStream = (event) => {
      if (event.target.getAttribute("action") === "refresh") this.schedule()
    }
    document.addEventListener("turbo:before-stream-render", this.onStream)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.onStream)
    clearTimeout(this.timer)
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => window.Turbo.session.refresh(document.baseURI), this.delayValue)
  }
}
