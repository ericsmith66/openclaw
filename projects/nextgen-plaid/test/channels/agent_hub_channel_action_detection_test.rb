require "test_helper"

class AgentHubChannelActionDetectionTest < ActionCable::Channel::TestCase
  tests AgentHubChannel

  setup do
    @user = users(:one)
    stub_connection current_user: @user
    Artifact.destroy_all
    @artifact = Artifact.create!(
      name: "Test Artifact",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP"
    )

    # Mock SmartProxyClient to return a response with an action tag
    @mock_client = Minitest::Mock.new
    @mock_response = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "I've identified the artifact. [ACTION: MOVE_TO_ANALYSIS: #{@artifact.id}]"
        }
      } ]
    }
  end

  test "detects MOVE_TO_ANALYSIS action in SAP response" do
    # Use a user with admin role as required by the channel
    @admin = User.create!(email: "admin_action_#{rand(1000)}@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: @admin

    AgentHub::SmartProxyClient.stub :new, @mock_client do
      @mock_client.expect :chat, @mock_response do |_messages, kwargs|
        # Verify keyword arguments are passed
        assert kwargs.key?(:stream_to)
        assert kwargs.key?(:message_id)
        true
      end

      # Stub Thread.new to execute synchronously for testing
      Thread.stub :new, ->(&block) { block.call } do
        subscribe agent_id: "sap"

        perform :speak, {
          "content" => "lets work on item #{@artifact.id}",
          "model" => "gpt-4"
        }
      end

      # Now we check the broadcasts on the channel
      all_broadcasts = broadcasts("agent_hub_channel_sap")

      # Filter for confirmation_bubble
      bubble_broadcast = all_broadcasts.find { |b| b.include?("confirmation_bubble") }

      assert bubble_broadcast, "Should have broadcasted a confirmation bubble. Broadcasts: #{all_broadcasts.inspect}"
      assert_match /Move to Analysis/, bubble_broadcast
      assert_match /data-confirmation-bubble-artifact-id-value=\\\"#{@artifact.id}\\\"/, bubble_broadcast
    end
  end

  test "handles silent actions automatically" do
    @admin = User.create!(email: "admin_silent_#{rand(1000)}@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: @admin

    silent_response = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Starting the build. [ACTION: START_BUILD: #{@artifact.id}]"
        }
      } ]
    }

    AgentHub::SmartProxyClient.stub :new, @mock_client do
      @mock_client.expect :chat, silent_response do |_messages, _kwargs|
        true
      end

      Thread.stub :new, ->(&block) { block.call } do
        subscribe agent_id: "sap"
        perform :speak, { "content" => "start build", "model" => "gpt-4" }
      end

      @artifact.reload
      # START_BUILD is mapped to 'approve' action in WorkflowBridge,
      # which moves 'backlog' to 'ready_for_analysis' in Artifact model
      assert_equal "ready_for_analysis", @artifact.phase

      all_broadcasts = broadcasts("agent_hub_channel_sap")
      system_notif = all_broadcasts.find { |b| b.include?("⚡ **[System Notification]**") }
      assert system_notif, "Should have broadcasted a system notification for silent action"
    end
  end

  test "warns on legacy slash commands" do
    @admin = User.create!(email: "admin_legacy_#{rand(1000)}@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: @admin

    subscribe agent_id: "sap"
    perform :speak, { "content" => "/approve", "model" => "gpt-4" }

    all_broadcasts = broadcasts("agent_hub_channel_sap")
    legacy_warning = all_broadcasts.find { |b| b.include?("⚠️ [Legacy]: Slash commands like `/approve` are deprecated") }
    assert legacy_warning
  end
end
