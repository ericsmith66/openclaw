require "test_helper"

class PersonaChatChannelTest < ActionCable::Channel::TestCase
  test "subscribes for valid persona and authenticated user" do
    user = users(:one)
    stub_connection current_user: user

    conversation = PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:70b",
      title: "Chat Jan 01"
    )

    subscribe persona_id: "financial-advisor", conversation_id: conversation.id
    assert subscription.confirmed?
    assert_has_stream "persona_chat:#{user.id}:financial-advisor:#{conversation.id}"
  end

  test "rejects subscription for invalid persona" do
    user = users(:one)
    stub_connection current_user: user

    subscribe persona_id: "does-not-exist"
    assert subscription.rejected?
  end

  test "handle_message persists user message for owned conversation" do
    user = users(:one)
    stub_connection current_user: user

    conversation = PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:70b",
      title: "Chat Jan 01"
    )

    subscribe persona_id: "financial-advisor", conversation_id: conversation.id

    assert_difference -> { PersonaMessage.count }, 2 do
      perform :handle_message, { "conversation_id" => conversation.id, "content" => "Hello" }
    end

    user_message = PersonaMessage.where(persona_conversation_id: conversation.id, role: "user").order(:created_at).last
    assert_equal "Hello", user_message.content

    assistant_message = PersonaMessage.where(persona_conversation_id: conversation.id, role: "assistant").order(:created_at).last
    assert assistant_message.present?
  end

  test "handle_message streams assistant and broadcasts message_finished" do
    user = users(:one)
    stub_connection current_user: user

    conversation = PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "llama3.1:70b",
      title: "Chat Jan 01"
    )

    subscribe persona_id: "financial-advisor", conversation_id: conversation.id

    fake_client = Object.new
    def fake_client.chat(_messages, message_id: nil, broadcast_stream: nil, **_kwargs)
      _ = message_id
      _ = broadcast_stream
      { "choices" => [ { "message" => { "content" => "Hello back" } } ] }
    end

    AgentHub::SmartProxyClient.stub(:new, fake_client) do
      assert_broadcasts("persona_chat:#{user.id}:financial-advisor:#{conversation.id}", 1) do
        perform :handle_message, { "conversation_id" => conversation.id, "content" => "Hello" }
      end
    end

    conversation.reload
    assistant_contents = PersonaMessage.where(persona_conversation_id: conversation.id, role: "assistant")
      .order(:created_at)
      .pluck(:content)

    assert_includes assistant_contents, "Hello back"
  end
end
