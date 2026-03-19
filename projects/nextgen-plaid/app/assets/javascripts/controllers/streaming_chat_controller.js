// NOTE:
// This controller is served from the Propshaft asset load path (`app/assets/javascripts`).
// In this app, Propshaft is not indexing `app/javascript`, so controllers placed there
// are not resolvable by `asset_path` and therefore do not appear in the rendered importmap.
//
// Stimulus identifier: `streaming-chat`

import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { personaId: String, conversationId: Number }
  static targets = ["messages", "input", "status", "debugLog"]

  connect() {
    this.debugEnabled = new URLSearchParams(window.location.search).get("debug") === "1"
    this.debugLines = []
    this.setStatus("connecting")

    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      // eslint-disable-next-line no-console
      console.log("[streaming-chat] connect persona=", this.personaIdValue, "conversation=", this.conversationIdValue)
      window.streamingChat = this
    }
    this.debugLog(`connect persona=${this.personaIdValue} conversation=${this.conversationIdValue}`)
    this.subscribe()
  }

  disconnect() {
    if (this.channel) this.channel.unsubscribe()
    this.streamingActive = false
    this.setStatus("disconnected")
    this.debugLog("disconnect")
  }

  subscribe() {
    this.channel = createConsumer().subscriptions.create(
      {
        channel: "PersonaChatChannel",
        persona_id: this.personaIdValue,
        conversation_id: this.conversationIdValue
      },
      {
        received: (data) => this.handleReceived(data),
        connected: () => this.handleConnected(),
        disconnected: () => this.handleDisconnected()
      }
    )
  }

  handleConnected() {
    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      // eslint-disable-next-line no-console
      console.log("[streaming-chat] connected")
    }
    this.setStatus("connected")
    this.debugLog("connected")
  }

  handleDisconnected() {
    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      // eslint-disable-next-line no-console
      console.log("[streaming-chat] disconnected")
    }
    this.stopClientTimeout()
    this.stopThinking()
    this.streamingActive = false
    this.showToast("Chat connection lost—refresh page")
    this.setStatus("disconnected")
    this.debugLog("disconnected")
  }

  send(event) {
    event.preventDefault()

    const content = this.inputTarget.value.trim()
    if (!content) return

    this.lastSentContent = content

    this.appendUserMessage(content)
    this.inputTarget.value = ""

    // Show an immediate “thinking” indicator so users see the assistant is working
    // before the first streaming token arrives.
    this.streamingActive = true
    this.startThinking()

    // UX fallback: if the server times out or the socket drops without an explicit
    // error event, we still show a user-facing timeout message.
    this.startClientTimeout()

    this.channel.perform("handle_message", {
      conversation_id: this.conversationIdValue,
      content: content
    })

    if (new URLSearchParams(window.location.search).get("debug") === "1") {
      // eslint-disable-next-line no-console
      console.log("[streaming-chat] performed handle_message")
    }
    this.debugLog("performed handle_message")
  }

  handleReceived(data) {
    // Any received event means the request is still alive. Keep extending the client
    // timeout while we are actively streaming.
    if (this.streamingActive) this.startClientTimeout()

    this.debugLog(`received ${data.type || "(no_type)"}`)
    if (data.type === "error") {
      this.finishStreaming()
      this.stopThinking()
      this.stopClientTimeout()
      this.streamingActive = false
      this.showToast(data.message || "Something went wrong", data.retryable)
      return
    }

    if (data.type === "keepalive") {
      // If a request is in-flight but the provider is streaming tool-calls (no tokens yet),
      // ensure the user still sees an immediate thinking indicator.
      this.streamingActive = true
      this.startThinking()
      return
    }

    if (data.type === "token") {
      this.stopThinking()
      this.appendAssistantToken(data.message_id, data.token)
      return
    }

    if (data.type === "message_finished") {
      this.stopThinking()
      this.finishAssistantMessage(data.message_id, data.content, data.content_html)
      this.finishStreaming()
      this.stopClientTimeout()
      this.streamingActive = false
    }
  }

  startClientTimeout() {
    this.stopClientTimeout()

    // High enough to avoid false positives with slower models.
    // This only covers the case where no server error event makes it to the client.
    this.clientTimeoutMs = 180_000
    this.clientTimeout = setTimeout(() => {
      this.stopThinking()
      this.streamingActive = false
      this.showToast("Request timed out. Try again or switch to a smaller model.", true)
      this.debugLog("client_timeout")
    }, this.clientTimeoutMs)
  }

  stopClientTimeout() {
    if (this.clientTimeout) clearTimeout(this.clientTimeout)
    this.clientTimeout = null
  }

  startThinking() {
    // If we already have an active assistant bubble (streaming), don’t add another.
    if (this.pendingThinkingEl) return

    const wrapper = document.createElement("div")
    wrapper.className = "chat chat-start"
    wrapper.innerHTML = `
      <div class="chat-bubble">
        <span class="loading loading-dots loading-sm"></span>
      </div>
    `

    this.messagesTarget.appendChild(wrapper)
    this.pendingThinkingEl = wrapper
    this.scrollToBottom()
  }

  stopThinking() {
    if (!this.pendingThinkingEl) return
    this.pendingThinkingEl.remove()
    this.pendingThinkingEl = null
  }

  debugLog(line) {
    if (!this.debugEnabled) return
    if (!this.hasDebugLogTarget) return

    const ts = new Date().toISOString().slice(11, 19)
    this.debugLines.push(`[${ts}] ${line}`)
    this.debugLines = this.debugLines.slice(-50)
    this.debugLogTarget.textContent = this.debugLines.join("\n")
  }

  setStatus(status) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = status
  }

  appendUserMessage(text) {
    const wrapper = document.createElement("div")
    wrapper.className = "chat chat-end"
    wrapper.innerHTML = `<div class="chat-bubble chat-bubble-primary"></div>`
    wrapper.querySelector(".chat-bubble").textContent = text
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
  }

  appendAssistantToken(messageId, token) {
    this.ensureAssistantMessage(messageId)
    const bubble = this.assistantBubble
    const current = bubble.dataset.raw || ""
    bubble.dataset.raw = current + token
    bubble.textContent = bubble.dataset.raw
    this.startStreamingCursor()
    this.scrollToBottom()
  }

  finishAssistantMessage(messageId, content, contentHtml) {
    this.ensureAssistantMessage(messageId)
    this.assistantBubble.dataset.raw = content || ""
    if (contentHtml) {
      this.assistantBubble.innerHTML = contentHtml
    } else {
      this.assistantBubble.textContent = this.assistantBubble.dataset.raw
    }
    this.removeStreamingCursor()
    this.scrollToBottom()
  }

  ensureAssistantMessage(messageId) {
    if (this.assistantBubble && this.assistantBubble.dataset.messageId === String(messageId)) return

    const wrapper = document.createElement("div")
    wrapper.className = "chat chat-start"
    wrapper.innerHTML = `<div class="chat-bubble" data-message-id="${messageId}" data-raw=""></div>`
    this.messagesTarget.appendChild(wrapper)
    this.assistantBubble = wrapper.querySelector(".chat-bubble")
  }

  startStreamingCursor() {
    if (this.cursorEl) return
    this.cursorEl = document.createElement("span")
    this.cursorEl.className = "streaming-cursor"
    this.cursorEl.textContent = "▍"
    this.assistantBubble.appendChild(this.cursorEl)
  }

  removeStreamingCursor() {
    if (this.cursorEl) this.cursorEl.remove()
    this.cursorEl = null
  }

  finishStreaming() {
    this.removeStreamingCursor()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  showToast(message) {
    const wrapper = document.createElement("div")
    wrapper.className = "toast toast-top toast-end z-50"

    const actions = document.createElement("div")
    actions.className = "flex gap-2 ml-2"

    const cancelBtn = document.createElement("button")
    cancelBtn.className = "btn btn-xs btn-ghost"
    cancelBtn.textContent = "Dismiss"
    cancelBtn.addEventListener("click", () => wrapper.remove())
    actions.appendChild(cancelBtn)

    wrapper.innerHTML = `<div class="alert alert-info"><span>${message}</span></div>`
    wrapper.querySelector(".alert").appendChild(actions)

    if (arguments.length > 1 && arguments[1] === true && this.lastSentContent) {
      const retryBtn = document.createElement("button")
      retryBtn.className = "btn btn-xs btn-primary"
      retryBtn.textContent = "Retry"
      retryBtn.addEventListener("click", () => {
        wrapper.remove()
        this.retryLast()
      })
      actions.appendChild(retryBtn)
    }

    document.body.appendChild(wrapper)
    setTimeout(() => wrapper.remove(), 8000)
  }

  retryLast() {
    if (!this.lastSentContent) return

    this.streamingActive = true
    this.startThinking()
    this.startClientTimeout()

    this.channel.perform("handle_message", {
      conversation_id: this.conversationIdValue,
      content: this.lastSentContent
    })
  }
}
