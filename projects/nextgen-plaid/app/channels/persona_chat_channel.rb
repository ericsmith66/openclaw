class PersonaChatChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user

    persona_id = params[:persona_id].to_s
    reject if Personas.find(persona_id).blank?

    conversation_id = params[:conversation_id].to_i
    conversation = PersonaConversation.for_user(current_user).for_persona(persona_id).find_by(id: conversation_id)
    reject unless conversation

    stream_from stream_name(current_user.id, persona_id, conversation_id)
    Rails.logger.info("[PersonaChatChannel] subscribed user_id=#{current_user.id} persona_id=#{persona_id} conversation_id=#{conversation_id}")
  end

  def unsubscribed
    Rails.logger.info("[PersonaChatChannel] unsubscribed user_id=#{current_user&.id} persona_id=#{params[:persona_id]}")
  end

  # Client payload expected:
  # {"conversation_id": 123, "content": "hello"}
  def handle_message(data)
    persona_id = params[:persona_id].to_s
    conversation_id = data["conversation_id"].to_i
    content = data["content"].to_s
    raise ArgumentError, "Empty message" if content.strip.blank?

    assistant_message = nil

    conversation = PersonaConversation.for_user(current_user).for_persona(persona_id).find_by(id: conversation_id)
    raise ActiveRecord::RecordNotFound, "Conversation not found" unless conversation

    PersonaMessage.create!(persona_conversation: conversation, role: "user", content: content)

    # Create an assistant message row up-front so the client can render a stable
    # message id during token streaming. Use a placeholder so we never persist
    # a blank assistant bubble that later renders as "missing content".
    assistant_message = PersonaMessage.create!(
      persona_conversation: conversation,
      role: "assistant",
      content: "(thinking…)"
    )

    stream = stream_name(current_user.id, persona_id, conversation_id)

    persona = Personas.find(persona_id)
    system_prompt = (persona && persona["system_prompt"]).to_s

    rag_prefix = PersonaRagProvider.build_prefix(persona_id)

    model_id = normalize_model_id(conversation.llm_model)
    live_search_enabled = model_id.end_with?("-with-live-search")

    full_system = system_prompt
    if live_search_enabled
      full_system = [
        full_system,
        "\n\n--- LIVE SEARCH INSTRUCTIONS ---\n",
        "When the user asks about current events, market prices (e.g., TSLA price), breaking news, or anything time-sensitive, you MUST use the web search tool (web_search) before answering."
      ].join
    end
    full_system = [ full_system, "\n\n--- PERSONA RAG ---\n", rag_prefix ].join if rag_prefix.present?

    # Mode A: Always-current persona context providers.
    provider_keys = Array(persona && persona["context_providers"]).map(&:to_s)
    provider_metadata = {}
    provider_keys.each do |key|
      provider = PersonaContextProviders::Registry.build(key)
      result = provider.call(current_user)
      next if result.to_h["content"].to_s.strip.blank? && result.to_h[:content].to_s.strip.blank?

      content = result[:content] || result["content"]
      full_system = [ full_system, "\n\n", content.to_s ].join
      provider_metadata[key] = (result[:metadata] || result["metadata"] || {})
    rescue StandardError => e
      Rails.logger.warn("[PersonaChatChannel] context_provider_failed user_id=#{current_user.id} persona_id=#{persona_id} provider=#{key} error=#{e.class}:#{e.message}")
      next
    end

    messages = []
    messages << { role: "system", content: full_system } if full_system.present?
    messages += conversation.persona_messages.order(:created_at).map { |m| { role: m.role, content: m.content } }

    # Basic token/context overflow mitigation: keep the most recent messages under a soft cap.
    # (PRD 4-03: token overflow handling)
    messages = truncate_messages(messages, max_chars: 12_000)

    client = AgentHub::SmartProxyClient.new(model: model_id, stream: true)
    response = client.chat(messages, message_id: assistant_message.id, broadcast_stream: stream)

    if response["error"].present?
      raise StandardError, response["error"]
    end

    assistant_content = response.dig("choices", 0, "message", "content") || response.dig(:choices, 0, :message, :content)
    assistant_content = assistant_content.to_s
    sources = response.dig("smart_proxy", "sources")
    sources = Array(sources).map(&:to_s).reject(&:blank?).uniq

    assistant_message.update!(
      content: assistant_content,
      metadata: {
        "sources" => sources,
        "model" => conversation.llm_model,
        "provider_model" => response["model"].to_s,
        "context" => provider_metadata
      }.compact
    )

    content_html = PersonaChats::AssistantMessageRenderer.call(
      content: assistant_content,
      sources: sources,
      model: conversation.llm_model,
      provider_model: response["model"].to_s
    )

    ActionCable.server.broadcast(
      stream,
      {
        type: "message_finished",
        message_id: assistant_message.id,
        content: assistant_content,
        content_html: content_html,
        sources: sources,
        model: conversation.llm_model,
        provider_model: response["model"].to_s
      }
    )
    Rails.logger.info("[PersonaChatChannel] assistant_finished user_id=#{current_user.id} conversation_id=#{conversation.id} message_id=#{assistant_message.id}")
  rescue StandardError => e
    Rails.logger.error("[PersonaChatChannel] handle_message_failed user_id=#{current_user&.id} persona_id=#{persona_id} error=#{e.class}:#{e.message}")
    message = e.message.to_s
    retryable = true
    user_facing = if message.match?(/model.*not.*found|unknown model|does not exist/i)
      retryable = false
      "Model unavailable. Please pick a different model."
    elsif message.match?(/context|token|too long|maximum context/i)
      "Message too long / context limit reached. Please shorten your question or start a new conversation."
    elsif message.present?
      message
    else
      "Failed to send message"
    end

    # Persist a visible assistant error message instead of leaving a blank/placeholder.
    if assistant_message
      assistant_message.update(content: "⚠️ #{user_facing}")

      model = conversation ? conversation.llm_model.to_s : ""
      content_html = PersonaChats::AssistantMessageRenderer.call(
        content: assistant_message.content.to_s,
        sources: [],
        model: model,
        provider_model: ""
      )

      ActionCable.server.broadcast(
        stream_name(current_user.id, persona_id, conversation_id),
        {
          type: "message_finished",
          message_id: assistant_message.id,
          content: assistant_message.content.to_s,
          content_html: content_html,
          sources: [],
          model: model,
          provider_model: ""
        }
      )
    end

    ActionCable.server.broadcast(
      stream_name(current_user.id, persona_id, conversation_id),
      { type: "error", message: user_facing, retryable: retryable }
    )
  end

  private

  def stream_name(user_id, persona_id, conversation_id)
    "persona_chat:#{user_id}:#{persona_id}:#{conversation_id}"
  end

  def truncate_messages(messages, max_chars:)
    total = 0
    kept = []

    messages.reverse_each do |m|
      c = m[:content].to_s
      next if c.blank?

      total += c.length
      break if total > max_chars

      kept << m
    end

    kept.reverse
  end

  def normalize_model_id(model_id)
    # The smart_proxy live-search opt-in is expressed as `-with-live-search`.
    # Some users may refer to this generically as "grok-live-search".
    return "grok-4-with-live-search" if model_id.to_s == "grok-live-search"

    model_id.to_s
  end
end
