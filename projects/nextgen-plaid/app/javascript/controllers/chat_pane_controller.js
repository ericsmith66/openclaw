import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { marked } from "marked"

export default class extends Controller {
  static values = { agentId: String }
  static targets = ["messages"]

  connect() {
    this.isPolling = false
    this.messageTexts = {}
    this.subscribe()

    // Expose for manual testing if debug is enabled
    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      window.chatPane = this
    }
  }

  subscribe() {
    this.channel = createConsumer().subscriptions.create(
      { channel: "AgentHubChannel", agent_id: this.agentIdValue },
      {
        received: (data) => this.handleReceived(data),
        connected: () => this.handleConnected(),
        disconnected: () => this.handleDisconnected()
      }
    )
  }

  handleConnected() {
    console.log("Connected to AgentHubChannel")
    this.stopPolling()
  }

  handleDisconnected() {
    console.log("Disconnected from AgentHubChannel")
    this.startPolling()
  }

  startPolling() {
    if (this.isPolling) return
    this.isPolling = true
    console.log("Starting fallback polling...")
    this.pollTimer = setInterval(() => this.poll(), 5000)
  }

  stopPolling() {
    if (!this.isPolling) return
    this.isPolling = false
    console.log("Stopping fallback polling...")
    clearInterval(this.pollTimer)
  }

  async poll() {
    console.log("Polling for updates...")
    try {
      const response = await fetch(`/agent_hub/messages/${this.agentIdValue}`, {
        headers: { "Accept": "text/vnd.turbo-stream.html" }
      })
      if (response.ok) {
        const stream = await response.text()
        Turbo.renderStreamMessage(stream)
      }
    } catch (error) {
      console.error("Polling failed:", error)
    }
  }

  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
  }

  handleReceived(data) {
    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      console.log("[chat_pane_controller] Received:", data)
    }
    if (data.type === "token") {
      this.appendToken(data)
    } else if (data.type === "system") {
      this.appendSystemMessage(data)
    } else if (data.type === "message_finished") {
      this.finishMessage(data)
    } else if (data.type === "typing") {
      this.toggleTyping(data.status)
    } else if (data.type === "interrogation_request") {
      this.reportState(data.request_id)
    } else if (data.type === "confirmation_bubble") {
      this.appendConfirmationBubble(data)
    } else if (data.type === "confirmed") {
      this.handleConfirmed(data)
    }
  }

  appendConfirmationBubble(data) {
    const template = document.createElement("div")
    template.innerHTML = data.html
    const element = template.firstElementChild
    this.messagesTarget.appendChild(element)
    this.scrollToBottom()
  }

  appendSystemMessage(data) {
    const template = document.createElement("div")
    template.className = "flex justify-center my-2 w-full"
    template.innerHTML = `
      <div class="bg-base-300 text-base-content/70 text-[10px] uppercase tracking-wider px-3 py-1 rounded-full border border-base-content/10">
        ${data.content}
      </div>
    `
    this.messagesTarget.appendChild(template)
    this.scrollToBottom()
  }

  handleConfirmed(data) {
    const element = document.getElementById(`conf-${data.message_id}`)
    if (element) {
      const controller = this.application.getControllerForElementAndIdentifier(element, "confirmation-bubble")
      if (controller) {
        controller.markConfirmed()
      }
    }
  }

  reportState(requestId) {
    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      console.log("[chat_pane_controller] Sending interrogation report for:", requestId)
    }
    const state = {
      request_id: requestId,
      dom: document.documentElement.outerHTML.substring(0, 10000), // Cap DOM snapshot size
      console: "Snapshot taken at " + new Date().toISOString() // In a real app, we'd capture console logs
    }
    this.channel.perform("report_state", state)
  }

  finishMessage(data) {
    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      console.log("[chat_pane_controller] Finishing message:", data.message_id)
    }
    const messageId = `message-${data.message_id}`
    const messageElement = document.getElementById(messageId)
    if (messageElement) {
      const contentElement = messageElement.querySelector(".content")
      if (contentElement) {
        if (data.thought_html) {
          let thoughtContainer = contentElement.querySelector(".thought-container")
          if (thoughtContainer) {
            thoughtContainer.querySelector(".thought-text").innerHTML = data.thought_html
          }
        }
        if (data.content_html) {
          contentElement.querySelector(".text").innerHTML = data.content_html
          if (new URLSearchParams(window.location.search).get("debug") === "1") {
            console.log("[chat_pane_controller] Updated content HTML for:", messageId)
          }
        }
        
        // Update rag_request_id if provided
        if (data.rag_request_id) {
          const inspectBtn = messageElement.querySelector("[data-action='click->chat-pane#inspectContext']")
          if (inspectBtn) {
            inspectBtn.dataset.ragRequestId = data.rag_request_id
          }
        }
      }
    } else {
      console.warn("[chat_pane_controller] Could not find message element to finish:", messageId)
    }
    this.scrollToBottom()
  }

  appendToken(data) {
    const messageId = `message-${data.message_id}`
    let messageElement = document.getElementById(messageId)

    if (!messageElement) {
      messageElement = this.createMessageElement(data)
      this.messagesTarget.appendChild(messageElement)
    }

    const contentElement = messageElement.querySelector(".content")
    if (data.thought) {
      let thoughtContainer = contentElement.querySelector(".thought-container")
      if (!thoughtContainer) {
        thoughtContainer = this.createThoughtContainer(contentElement)
      }
      const key = `${messageId}-thought`
      this.messageTexts[key] = (this.messageTexts[key] || "") + data.token
      thoughtContainer.querySelector(".thought-text").innerHTML = marked.parse(this.messageTexts[key])
    } else {
      this.messageTexts[messageId] = (this.messageTexts[messageId] || "") + data.token
      contentElement.querySelector(".text").innerHTML = marked.parse(this.messageTexts[messageId])
    }
    
    this.scrollToBottom()
  }

  createMessageElement(data) {
    const debug = new URLSearchParams(window.location.search).get("debug") === "1"
    const template = document.createElement("div")
    template.id = `message-${data.message_id}`
    template.className = "chat chat-start group"
    template.innerHTML = `
      <div class="chat-header flex items-center gap-2">
        ${data.model ? `<span class="badge badge-sm badge-outline">${data.model}</span>` : ""}
        ${debug ? `
          <button class="btn btn-ghost btn-xs btn-circle opacity-0 group-hover:opacity-100 transition-opacity" 
                  data-action="click->chat-pane#inspectContext" 
                  title="Inspect Context">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
          </button>
        ` : ""}
      </div>
      <div class="chat-bubble content bg-base-300 border border-base-content/10 flex flex-col gap-2 prose prose-sm max-w-none">
        <div class="text"></div>
      </div>
    `
    return template
  }

  createThoughtContainer(container) {
    const el = document.createElement("div")
    el.className = "thought-container bg-base-200 p-2 rounded border border-base-content/5 mb-2 prose prose-sm max-w-none"
    el.innerHTML = `
      <div class="text-[10px] uppercase font-bold text-gray-500 mb-1 not-prose">Agent Thought</div>
      <div class="thought-text text-gray-400 italic text-sm"></div>
    `
    container.prepend(el)
    return el
  }

  async inspectContext(event) {
    const ragRequestId = event.currentTarget.dataset.ragRequestId
    const modalToggle = document.getElementById("context-inspect-modal")
    const modalContent = document.getElementById("context-inspect-content")
    
    if (modalToggle && modalContent) {
      modalToggle.checked = true
      modalContent.innerHTML = '<span class="loading loading-spinner loading-md"></span>'
      
      try {
        let url = "/agent_hubs/inspect_context"
        if (ragRequestId) {
          url += `?rag_request_id=${ragRequestId}`
        }
        const response = await fetch(url)
        const data = await response.json()
        modalContent.textContent = JSON.stringify(data, null, 2)
      } catch (error) {
        modalContent.textContent = "Error fetching context: " + error.message
      }
    }
  }

  createThoughtElement(container) {
    return this.createThoughtContainer(container).querySelector(".thought-text")
  }

  toggleTyping(status) {
    const indicator = document.getElementById(`typing-indicator-${this.agentIdValue}`)
    if (indicator) {
      if (status === "start") {
        indicator.classList.remove("hidden")
        
        // Auto-hide after 45 seconds to prevent stuck bubble
        if (this.typingTimeout) clearTimeout(this.typingTimeout)
        this.typingTimeout = setTimeout(() => {
          indicator.classList.add("hidden")
        }, 45000)
      } else {
        if (this.typingTimeout) clearTimeout(this.typingTimeout)
        indicator.classList.add("hidden")
      }
    }
    this.scrollToBottom()
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
