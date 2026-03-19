require "test_helper"

class PersonaChats::ModelSelectorComponentTest < ViewComponent::TestCase
  test "renders dropdown with current model" do
    conversation = OpenStruct.new(id: 1, llm_model: "llama3.1:70b")
    models = %w[llama3.1:70b llama3.1:8b]

    render_inline(
      PersonaChats::ModelSelectorComponent.new(
        persona_id: "financial-advisor",
        conversation: conversation,
        available_models: models
      )
    )

    assert_text "Model: Llama 3.1 70B"
    assert_selector "form button", text: "Llama 3.1 8B"
  end

  test "shows disabled state when models unavailable" do
    conversation = OpenStruct.new(id: 1, llm_model: "llama3.1:70b")

    render_inline(
      PersonaChats::ModelSelectorComponent.new(
        persona_id: "financial-advisor",
        conversation: conversation,
        available_models: []
      )
    )

    assert_selector ".btn-disabled"
  end
end
