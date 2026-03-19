class ConversationSidebarComponent < ViewComponent::Base
  def initialize(conversations:, active_run: nil, active_persona_id: nil)
    @conversations = conversations
    @active_run = active_run
    @active_persona_id = active_persona_id
  end
end
