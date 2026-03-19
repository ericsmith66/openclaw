require "test_helper"

class PersonaTabsComponentTest < ViewComponent::TestCase
  test "renders persona tabs and highlights active one with correct color" do
    personas = [
      { id: "sap", name: "SAP" },
      { id: "conductor", name: "Conductor" },
      { id: "cwa", name: "CWA" },
      { id: "ai_financial_advisor", name: "AiFinancialAdvisor" },
      { id: "debug", name: "Debug" }
    ]

    # Test SAP
    render_inline(PersonaTabsComponent.new(personas: personas, active_persona_id: "sap"))
    assert_selector "a.tab-active.bg-blue-600", text: "SAP"

    # Test Conductor
    render_inline(PersonaTabsComponent.new(personas: personas, active_persona_id: "conductor"))
    assert_selector "a.tab-active.bg-emerald-600", text: "Conductor"

    # Test CWA
    render_inline(PersonaTabsComponent.new(personas: personas, active_persona_id: "cwa"))
    assert_selector "a.tab-active.bg-amber-500", text: "CWA"

    # Test AiFinancialAdvisor
    render_inline(PersonaTabsComponent.new(personas: personas, active_persona_id: "ai_financial_advisor"))
    assert_selector "a.tab-active.bg-violet-600", text: "AiFinancialAdvisor"

    # Test Debug
    render_inline(PersonaTabsComponent.new(personas: personas, active_persona_id: "debug"))
    assert_selector "a.tab-active.bg-red-600", text: "Debug"
  end
end
