module PersonaChats
  class SidebarComponent < ViewComponent::Base
    def initialize(persona_id:, conversations:, active_conversation_id:, next_page: nil)
      @persona_id = persona_id
      @conversations = conversations
      @active_conversation_id = active_conversation_id
      @next_page = next_page
    end

    private

    attr_reader :persona_id, :conversations, :active_conversation_id, :next_page
  end
end
