class TitleGenerationJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  LIGHTWEIGHT_MODEL = "llama3.1:8b".freeze

  def perform(persona_conversation_id)
    conversation = PersonaConversation.find_by(id: persona_conversation_id)
    return unless conversation

    first_user_message = conversation.persona_messages.user_role.order(:created_at).first
    return unless first_user_message

    client = AgentHub::SmartProxyClient.new(model: LIGHTWEIGHT_MODEL, stream: false)
    prompt = "Summarize this message in 3-5 words for a chat title: #{first_user_message.content}"

    response = client.chat([
      { role: "user", content: prompt }
    ])

    title = response.dig("choices", 0, "message", "content").to_s.strip
    title = title.gsub(/[\r\n]+/, " ").gsub(/\s+/, " ")
    title = title.delete_prefix('"').delete_suffix('"').strip
    title = title.truncate(50, omission: "")

    if title.blank?
      Rails.logger.warn("[TitleGenJob] empty_title conversation_id=#{conversation.id}")
      return
    end

    conversation.update!(title: title)
    Rails.logger.info("[TitleGenJob] success conversation_id=#{conversation.id}")
  rescue Faraday::TimeoutError => e
    Rails.logger.warn("[TitleGenJob] timeout conversation_id=#{persona_conversation_id} error=#{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("[TitleGenJob] error conversation_id=#{persona_conversation_id} error=#{e.class}:#{e.message}")
    raise
  end
end
