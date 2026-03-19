require "test_helper"

class PersonaRagProviderTest < ActiveSupport::TestCase
  test "loads persona-scoped markdown docs" do
    prefix = PersonaRagProvider.build_prefix("financial-advisor")
    assert_includes prefix, "Investment Principles"
    assert_includes prefix, "knowledge_base/personas/financial_advisor/investment_principles.md"
  end

  test "returns empty string for unknown persona directory" do
    assert_equal "", PersonaRagProvider.build_prefix("does-not-exist")
  end
end
