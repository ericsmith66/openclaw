import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "autocomplete", "model", "fileInput", "filePreviews"]
  static values = { agentId: String, runId: Number }

  connect() {
    this.selectedFiles = []
    console.log("[input_bar_controller] Connected with runIdValue:", this.runIdValue, "hasRunIdValue:", this.hasRunIdValue, "type:", typeof this.runIdValue)
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit()
    }
  }

  handleInput(event) {
    const value = this.inputTarget.value
    if (value.startsWith("/")) {
      this.autocompleteTarget.classList.remove("hidden")
    } else {
      this.autocompleteTarget.classList.add("hidden")
    }
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files)
    this.selectedFiles = this.selectedFiles.concat(files)
    this.updateFilePreviews()
  }

  updateFilePreviews() {
    this.filePreviewsTarget.innerHTML = ""
    this.selectedFiles.forEach((file, index) => {
      const preview = document.createElement("div")
      preview.className = "badge badge-info gap-2 text-xs"
      preview.innerHTML = `
        ${file.name}
        <button type="button" data-action="click->input-bar#removeFile" data-index="${index}" class="hover:text-white">✕</button>
      `
      this.filePreviewsTarget.appendChild(preview)
    })
  }

  removeFile(event) {
    const index = parseInt(event.target.dataset.index)
    this.selectedFiles.splice(index, 1)
    this.updateFilePreviews()
  }

  selectCommand(event) {
    const command = event.target.textContent.trim()
    this.inputTarget.value = command + " "
    this.autocompleteTarget.classList.add("hidden")
    this.inputTarget.focus()
  }

  async submit() {
    const content = this.inputTarget.value.trim()
    if (content === "" && this.selectedFiles.length === 0) return

    console.log("[input_bar_controller] Submitting message with runIdValue:", this.runIdValue)

    let attachments = []
    if (this.selectedFiles.length > 0 && this.runIdValue) {
      attachments = await this.uploadFiles()
    }

    this.appendUserMessage(content, attachments)
    this.inputTarget.value = ""
    this.selectedFiles = []
    this.updateFilePreviews()
    this.autocompleteTarget.classList.add("hidden")
    
    const model = this.hasModelTarget ? this.modelTarget.value : null
    
    // Send to server via Action Cable
    const chatPane = document.querySelector(`[data-controller='chat-pane'][data-chat-pane-agent-id-value='${this.agentIdValue}']`)
    if (chatPane) {
      const controller = this.application.getControllerForElementAndIdentifier(chatPane, "chat-pane")
      if (controller && controller.channel) {
        // Only send conversation_id if the value is defined and valid
        const conversationId = this.hasRunIdValue ? this.runIdValue : null
        console.log("[input_bar_controller] Sending to channel with conversation_id:", conversationId, "(hasRunIdValue:", this.hasRunIdValue, "runIdValue:", this.runIdValue, ")")
        controller.channel.perform("speak", { 
          content: content, 
          model: model, 
          attachment_ids: attachments.map(a => a.id),
          conversation_id: conversationId
        })
      }
    }
  }

  async uploadFiles() {
    const formData = new FormData()
    formData.append("run_id", this.runIdValue)
    this.selectedFiles.forEach(file => {
      formData.append("files[]", file)
    })

    try {
      const response = await fetch("/agent_hub/uploads", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: formData
      })
      const data = await response.json()
      return data.success ? data.attachments : []
    } catch (error) {
      console.error("Upload failed", error)
      return []
    }
  }

  appendUserMessage(content, attachments = []) {
    const messagesContainer = document.getElementById(`messages-${this.agentIdValue}`)
    if (!messagesContainer) return

    const messageId = `user-${Date.now()}`
    const template = document.createElement("div")
    template.id = messageId
    template.className = "chat chat-end"
    
    let attachmentHtml = ""
    if (attachments.length > 0) {
      attachmentHtml = `<div class="mt-2 flex flex-col gap-1">
        ${attachments.map(a => `
          <a href="${a.url}" target="_blank" class="flex items-center gap-1 text-xs underline opacity-80">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
            </svg>
            ${a.filename}
          </a>
        `).join("")}
      </div>`
    }

    template.innerHTML = `
      <div class="chat-header">You</div>
      <div class="chat-bubble chat-bubble-primary">
        <div>${content}</div>
        ${attachmentHtml}
      </div>
    `
    messagesContainer.appendChild(template)
    
    // Auto scroll the chat pane
    const chatPane = messagesContainer.closest("[data-controller='chat-pane']")
    if (chatPane) {
      chatPane.scrollTop = chatPane.scrollHeight
    }
  }
}
