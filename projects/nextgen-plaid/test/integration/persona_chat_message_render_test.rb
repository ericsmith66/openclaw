require "test_helper"

class PersonaChatMessageRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "renders assistant message markdown as sanitized HTML" do
    user = users(:one)
    sign_in user

    conversation = PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:70b",
      title: "Chat Jan 01"
    )

    message = PersonaMessage.create!(
      persona_conversation: conversation,
      role: "assistant",
      content: "### Hello\n\n- one\n- two"
    )

    get persona_chat_render_message_path(persona_id: "financial-advisor", id: message.id)
    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal message.id, payload["message_id"]
    assert_includes payload["content_html"], "<h3"
    assert_includes payload["content_html"], "<ul"
  end

  test "does not allow rendering another user's message" do
    owner = users(:one)
    other = users(:two)

    conversation = PersonaConversation.create!(
      user: owner,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:70b",
      title: "Chat Jan 01"
    )

    message = PersonaMessage.create!(
      persona_conversation: conversation,
      role: "assistant",
      content: "### Secret"
    )

    sign_in other
    get persona_chat_render_message_path(persona_id: "financial-advisor", id: message.id)
    assert_response :not_found
  end
end
