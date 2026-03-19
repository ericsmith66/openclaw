import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actions", "status", "result"]
  static values = { messageId: String, command: String, artifactId: String, label: String }

  confirm() {
    this.actionsTarget.classList.add("hidden")
    this.statusTarget.classList.remove("hidden")

    // Safety timeout: if we don't get a confirmation within 30 seconds, reset the UI
    this.confirmTimeout = setTimeout(() => {
      if (!this.statusTarget.classList.contains("hidden")) {
        this.statusTarget.classList.add("hidden")
        this.actionsTarget.classList.remove("hidden")
        console.warn("Confirmation timeout for message:", this.messageIdValue)
      }
    }, 30000)

    // Find the chat-pane controller to send the confirmation via Action Cable
    const chatPane = this.element.closest("[data-controller='chat-pane']")
    if (chatPane) {
      const controller = this.application.getControllerForElementAndIdentifier(chatPane, "chat-pane")
      if (controller && controller.channel) {
        controller.channel.perform("confirm_action", { 
          message_id: this.messageIdValue, 
          command: this.commandValue,
          label: this.labelValue,
          artifact_id: this.artifactIdValue
        })
      } else {
        console.error("ChatPane controller or channel not found", { controller, channel: controller?.channel })
        this.resetUI()
      }
    } else {
      console.error("Closest chat-pane not found for confirmation bubble")
      this.resetUI()
    }
  }

  resetUI() {
    if (this.confirmTimeout) clearTimeout(this.confirmTimeout)
    this.statusTarget.classList.add("hidden")
    this.actionsTarget.classList.remove("hidden")
  }

  cancel() {
    if (this.confirmTimeout) clearTimeout(this.confirmTimeout)
    this.element.remove()
  }

  // This might be called via a broadcast if we want server-side confirmation of completion
  markConfirmed() {
    if (this.confirmTimeout) clearTimeout(this.confirmTimeout)
    this.statusTarget.classList.add("hidden")
    this.resultTarget.classList.remove("hidden")
  }

  disconnect() {
    if (this.confirmTimeout) clearTimeout(this.confirmTimeout)
  }
}
