module PersonaChats
  class DisclaimerComponent < ViewComponent::Base
    def initialize(text: "Educational simulation – AI responses for learning")
      @text = text
    end

    private

    attr_reader :text

    def tooltip
      "This is a simulated conversation with an AI persona. Responses are for educational purposes. Always verify important information."
    end
  end
end
