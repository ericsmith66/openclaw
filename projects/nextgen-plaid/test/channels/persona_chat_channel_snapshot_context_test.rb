require "test_helper"

class PersonaChatChannelSnapshotContextTest < ActionCable::Channel::TestCase
  tests PersonaChatChannel

  test "injects financial snapshot context for financial-advisor only" do
    user = users(:one)
    user.financial_snapshots.create!(
      snapshot_at: Time.current,
      schema_version: 1,
      status: :complete,
      data: { "core" => { "total_net_worth" => 1_000_000 } }
    )

    stub_connection current_user: user

    convo = PersonaConversation.create!(
      user: user,
      persona_id: "financial-advisor",
      llm_model: "grok-4-with-live-search",
      title: "Chat"
    )

    subscribe persona_id: "financial-advisor", conversation_id: convo.id

    fake_client = Object.new
    def fake_client.chat(messages, message_id: nil, broadcast_stream: nil, **_kwargs)
      _ = message_id
      _ = broadcast_stream
      $captured_messages = messages
      { "choices" => [ { "message" => { "content" => "ok" } } ], "model" => "grok-4" }
    end

    AgentHub::SmartProxyClient.stub(:new, fake_client) do
      perform :handle_message, { "conversation_id" => convo.id, "content" => "Hello" }
    end

    msgs = Array($captured_messages)
    system = msgs.first
    assert_equal "system", system[:role]
    assert_includes system[:content], "FINANCIAL SNAPSHOT"
  ensure
    $captured_messages = nil
  end

  test "does not inject snapshot context for other personas" do
    user = users(:one)
    user.financial_snapshots.create!(
      snapshot_at: Time.current,
      schema_version: 1,
      status: :complete,
      data: { "core" => { "total_net_worth" => 1_000_000 } }
    )

    # Create a dummy persona in-memory by stubbing Personas.find
    stubbed_persona = {
      "id" => "other",
      "system_prompt" => "hi",
      "context_providers" => []
    }

    stub_connection current_user: user
    convo = PersonaConversation.create!(user: user, persona_id: "financial-advisor", llm_model: "llama3.1:70b", title: "Chat")
    subscribe persona_id: "financial-advisor", conversation_id: convo.id

    fake_client = Object.new
    def fake_client.chat(messages, message_id: nil, broadcast_stream: nil, **_kwargs)
      _ = message_id
      _ = broadcast_stream
      $captured_messages = messages
      { "choices" => [ { "message" => { "content" => "ok" } } ], "model" => "llama" }
    end

    Personas.stub(:find, stubbed_persona) do
      AgentHub::SmartProxyClient.stub(:new, fake_client) do
        perform :handle_message, { "conversation_id" => convo.id, "content" => "Hello" }
      end
    end

    system = Array($captured_messages).first
    refute_includes system[:content], "FINANCIAL SNAPSHOT"
  ensure
    $captured_messages = nil
  end
end
