require "test_helper"

class PersonaChats::SidebarComponentTest < ViewComponent::TestCase
  test "renders conversations with title and preview" do
    conversations = [
      OpenStruct.new(id: 1, title: "Investment Strategy", last_message_preview: "Hello", updated_at: Time.current)
    ]

    render_inline(
      PersonaChats::SidebarComponent.new(
        persona_id: "financial-advisor",
        conversations: conversations,
        active_conversation_id: 1,
        next_page: nil
      )
    )

    assert_selector "form button", text: "New Conversation"
    assert_text "Investment Strategy"
    assert_text "Hello"
  end
end
