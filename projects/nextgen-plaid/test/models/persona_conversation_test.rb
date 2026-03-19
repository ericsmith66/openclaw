require "test_helper"

class PersonaConversationTest < ActiveSupport::TestCase
  setup do
    Personas.reset!
  end

  test "validates persona_id inclusion" do
    user = users(:one)
    conversation = PersonaConversation.new(user: user, persona_id: "invalid", llm_model: "m", title: "t")
    assert_not conversation.valid?
    assert_includes conversation.errors[:persona_id], "is not included in the list"
  end

  test "create_conversation inherits last-used model per persona" do
    user = users(:one)

    PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:8b",
      title: "Chat Jan 01"
    )

    new_conversation = PersonaConversation.create_conversation(user_id: user.id, persona_id: "financial-advisor")
    assert_equal "llama3.1:8b", new_conversation.llm_model
  end
end
