module PersonaChats
  class ModelSelectorComponent < ViewComponent::Base
    def initialize(persona_id:, conversation:, available_models:, toast: nil)
      @persona_id = persona_id
      @conversation = conversation
      @available_models = Array(available_models)
      @toast = toast
    end

    private

    attr_reader :persona_id, :conversation, :available_models, :toast

    def disabled?
      available_models.blank?
    end

    def display_name_for(model_id)
      # Expected formats: "llama3.1:70b", "llama3.1:8b"
      id = model_id.to_s
      return id if id.blank?

      live_search = id.end_with?("-with-live-search")
      base_id = live_search ? id.sub(/-with-live-search\z/, "") : id

      if base_id.start_with?("grok")
        name = base_id.tr("-", " ").titleize
        return live_search ? "#{name} (Live Search)" : name
      end

      if base_id.start_with?("claude")
        name = base_id.tr("-", " ").titleize
        return live_search ? "#{name} (Live Search)" : name
      end

      if (m = base_id.match(/\Allama(?<version>\d+(?:\.\d+)?)\s*:\s*(?<size>\d+)b\z/i))
        "Llama #{m[:version]} #{m[:size]}B"
      else
        id
      end
    end
  end
end
