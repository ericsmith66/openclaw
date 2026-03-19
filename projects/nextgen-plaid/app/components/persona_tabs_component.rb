class PersonaTabsComponent < ViewComponent::Base
  COLOR_MAP = {
    "sap" => "bg-blue-600",
    "conductor" => "bg-emerald-600",
    "cwa" => "bg-amber-500",
    "ai_financial_advisor" => "bg-violet-600",
    "debug" => "bg-red-600"
  }.freeze

  def initialize(personas:, active_persona_id:, available_models: nil, selected_model: nil)
    @personas = personas
    @active_persona_id = active_persona_id
    @available_models = available_models || AgentHub::ModelDiscoveryService.call
    @selected_model = selected_model
  end

  def active?(persona_id)
    @active_persona_id == persona_id
  end

  def tab_classes(persona_id)
    classes = "tab flex-nowrap"
    if active?(persona_id)
      color_class = COLOR_MAP[persona_id] || "bg-blue-500"
      classes += " tab-active #{color_class} text-white"
    end
    classes
  end
end
