module AgentHub
  # Handles chat orchestration, LLM interaction, and response streaming for AgentHub.
  #
  # This class extracts the "Fat Controller" logic from AgentHubChannel, focusing on
  # building RAG context, managing message history, and interfacing with SmartProxy.
  class ChatHandler
    # @return [User] The user participating in the chat
    attr_reader :user
    # @return [SapRun] The conversation context
    attr_reader :sap_run
    # @return [Proc] Callback to broadcast messages to ActionCable
    attr_reader :broadcast_callback

    # Initializes the ChatHandler.
    #
    # @param user [User] The user participating in the chat
    # @param sap_run [SapRun] The conversation context
    # @param broadcast_callback [Proc] Callback to broadcast messages to ActionCable
    def initialize(user:, sap_run:, broadcast_callback:)
      @user = user
      @sap_run = sap_run
      @broadcast_callback = broadcast_callback
    end

    # Processes a chat message.
    #
    # @param content [String] The user message content
    # @param model [String] The model to use for generation
    # @param target_agent_id [String] The ID of the agent being addressed
    # @param client_agent_id [String] The ID of the agent channel to broadcast back to
    # @return [Hash] Result of the chat operation
    def call(content:, model:, target_agent_id:, client_agent_id:)
      # Start typing indicator
      broadcast_callback.call(target_agent_id, { type: "typing", status: "start" })
      if client_agent_id != target_agent_id
        broadcast_callback.call(client_agent_id, { type: "typing", status: "start" })
      end

      # Generate unique message_id for this response
      message_id = "msg-#{Time.now.to_i}-#{rand(1000)}"

      # Update status if needed
      sap_run.update!(status: :running, started_at: Time.current) if sap_run.pending_status?

      # Auto-generate title from first message if still "New Conversation"
      sap_run.generate_title_from_first_message if sap_run.sap_messages.user_role.count == 0

      # Build RAG context using RagProvider
      rag_context = SapAgent::RagProvider.build_prefix("default", user.id, target_agent_id, sap_run.id)

      # Build messages array with context and conversation history
      messages = []

      # Add system message with RAG context and persona
      messages << {
        role: "system",
        content: "You are #{target_agent_id.upcase}. #{rag_context}"
      }

      # Load conversation history from SapMessages
      sap_run.sap_messages.order(:created_at).each do |msg|
        messages << { role: msg.role, content: msg.content }
      end

      # Add the new user message
      messages << { role: "user", content: content }

      # Save the user message to the database
      sap_run.sap_messages.create!(role: :user, content: content)

      # Create assistant message placeholder
      sap_run.reload
      rag_request_id = (sap_run.output_json || {})["last_rag_request_id"]
      assistant_message = sap_run.sap_messages.create!(role: :assistant, content: "", rag_request_id: rag_request_id, model: model)

      # Send to SmartProxyClient with full context
      client = AgentHub::SmartProxyClient.new(model: model, stream: true)
      response = client.chat(messages, stream_to: client_agent_id, message_id: message_id)

      if response.is_a?(Hash) && (response["error"].present? || response[:error].present?)
        error_message = (response["error"] || response[:error]).to_s
        error_message = "Sorry, I couldn't get a response from the model. Please try again." if error_message.blank?

        assistant_message.update!(content: error_message)
        broadcast_callback.call(client_agent_id, {
          type: "token",
          message_id: message_id,
          token: error_message
        })
        { status: :error, message: error_message }
      elsif response && (response["choices"] || response[:choices])
        full_content = (response.dig("choices", 0, "message", "content") || response.dig(:choices, 0, :message, :content))
        if full_content.present?
          assistant_message.update!(content: full_content)

          # Broadcast that the message is finished with rendered HTML
          broadcast_callback.call(client_agent_id, {
            type: "message_finished",
            message_id: message_id,
            content_html: Ai::MarkdownRenderer.render(full_content),
            rag_request_id: rag_request_id
          })

          # Workflow Bridge Action Detection (PRD-AH-011B)
          intents = AgentHub::WorkflowBridge.parse(full_content, role: "assistant", conversation: sap_run)
          { status: :ok, intents: intents, message_id: message_id, assistant_message: assistant_message }
        else
          { status: :empty_response }
        end
      else
        { status: :unknown_response }
      end
    ensure
      # Stop typing indicator
      broadcast_callback.call(target_agent_id, { type: "typing", status: "stop" })
      if client_agent_id != target_agent_id
        broadcast_callback.call(client_agent_id, { type: "typing", status: "stop" })
      end
    end
  end
end
