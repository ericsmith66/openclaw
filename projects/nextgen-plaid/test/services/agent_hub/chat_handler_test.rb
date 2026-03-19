require "test_helper"

class AgentHub::ChatHandlerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test_#{rand(1000)}@example.com", password: "password")
    @sap_run = SapRun.create_conversation(user_id: @user.id, persona_id: "agent_1")
    @broadcasts = []
    @callback = proc { |agent_id, payload| @broadcasts << { agent_id: agent_id, payload: payload } }
    @handler = AgentHub::ChatHandler.new(user: @user, sap_run: @sap_run, broadcast_callback: @callback)
  end

  test "call should build messages and call SmartProxyClient" do
    content = "Hello"
    model = "gpt-4"
    target_agent_id = "agent_1"
    client_agent_id = "agent_1"

    # Mock RagProvider
    SapAgent::RagProvider.stub :build_prefix, "Rag Context" do
      # Mock SmartProxyClient
      mock_client = Minitest::Mock.new
      mock_client.expect :chat, { "choices" => [ { "message" => { "content" => "Hi there" } } ] } do |messages, options|
        messages.is_a?(Array) && options[:stream_to] == client_agent_id
      end

      AgentHub::SmartProxyClient.stub :new, mock_client do
        result = @handler.call(content: content, model: model, target_agent_id: target_agent_id, client_agent_id: client_agent_id)

        assert_equal :ok, result[:status]
        assert_equal "Hi there", result[:assistant_message].content

        # Verify broadcasts (typing start, typing stop, message_finished)
        assert_any_broadcast "typing", "start"
        assert_any_broadcast "typing", "stop"
        assert_any_broadcast "message_finished", nil
      end
    end
  end

  private

  def assert_any_broadcast(type, status)
    assert @broadcasts.any? { |b| b[:payload][:type] == type && (status.nil? || b[:payload][:status] == status) },
           "Expected broadcast of type #{type} with status #{status}"
  end
end
