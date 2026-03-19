import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    const clicked = event.currentTarget
    const conversationId = clicked?.dataset?.conversationId
    if (conversationId) this.setActive(conversationId)

    // Mobile: close drawer after selecting a conversation.
    const drawer = document.getElementById("persona-chat-drawer")
    if (drawer) drawer.checked = false
  }

  setActive(conversationId) {
    const items = this.element.querySelectorAll(".conversation-item")
    items.forEach((el) => {
      if (el.id === `conversation-${conversationId}`) {
        el.classList.add("bg-base-300")
      } else {
        el.classList.remove("bg-base-300")
      }
    })
  }
}
