module PersonaChats
  class ChatPaneComponent < ViewComponent::Base
    def initialize(persona_id:, conversation: nil)
      @persona_id = persona_id
      @conversation = conversation
    end

    private

    attr_reader :persona_id, :conversation
  end
end
