import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hueSlider", "saturationSlider", "previewSwatch"]
  static values = {
    hue: Number,
    saturation: Number
  }

  connect() {
    this.updatePreview()
  }

  close() {
    this.element.remove()
  }

  close_if_background(event) {
    if (event.target === this.element) {
      this.close()
    }
  }

  update_preview() {
    const hue = this.hueSliderTarget.value
    const saturation = this.saturationSliderTarget.value
    this.previewSwatchTarget.style.backgroundColor = `hsl(${hue}, ${saturation}%, 50%)`
  }

  apply() {
    const hue = this.hueSliderTarget.value
    const saturation = this.saturationSliderTarget.value
    
    this.dispatch('colorApplied', {
      detail: { hue: parseInt(hue), saturation: parseInt(saturation) }
    })
    
    this.close()
  }
}
