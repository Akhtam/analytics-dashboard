import { Controller } from "@hotwired/stimulus"

// Submits the form whenever a filter control changes, so the dashboard updates
// without an explicit "Apply" click. `change` events from the selects bubble up
// to the form element this controller is attached to.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
