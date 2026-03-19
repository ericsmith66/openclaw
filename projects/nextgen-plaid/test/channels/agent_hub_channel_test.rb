require "test_helper"

class AgentHubChannelTest < ActionCable::Channel::TestCase
  setup do
    Rails.cache.clear
  end

  test "subscribes with agent_id as admin" do
    user = User.create!(email: "admin@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"
    assert subscription.confirmed?
    assert_has_stream "agent_hub_channel_test_agent"
  end

  test "rejects subscription for non-admin" do
    user = User.create!(email: "user@example.com", password: "password", roles: [])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"
    assert subscription.rejected?
  end

  test "enforces max streams cap for admins" do
    user = User.create!(email: "admin2@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user

    # In test env we use `config.cache_store = :null_store`, so writes won't persist.
    # Stub the cache read to simulate hitting the cap.
    Rails.cache.stub(:read, 5) do
      subscribe agent_id: "agent_overflow"
      assert subscription.rejected?
    end
  end

  test "interrogate broadcasts to the stream and report_state logs latency" do
    user = User.create!(email: "admin3@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"

    assert_broadcast_on("agent_hub_channel_test_agent", { type: "interrogation_request", request_id: "req123" }) do
      perform :interrogate, { "request_id" => "req123" }
    end

    # Test report_state with latency
    # We need to simulate the passage of time or just ensure it doesn't crash and logs something
    # Since we can't easily check Rails.logger in this test context without mocking,
    # we'll just verify it executes.
    perform :report_state, { "request_id" => "req123", "dom" => "<html></html>", "console" => "log" }
  end

  test "speak processes a regular message and triggers handle_chat" do
    user = User.create!(email: "admin5@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"

    # Stub Thread.new to execute synchronously for testing
    Thread.stub :new, ->(&block) { block.call } do
      # We expect a typing start broadcast
      assert_broadcast_on("agent_hub_channel_test_agent", { type: "typing", status: "start" }) do
        perform :speak, { "content" => "Hello agent", "model" => "test-model" }
      end
    end
  end

  test "speak processes a command with confirmation bubble" do
    user = User.create!(email: "admin6@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"

    # Expect 2 broadcasts: legacy warning and confirmation bubble
    assert_broadcasts("agent_hub_channel_test_agent", 2) do
      perform :speak, { "content" => "/approve", "model" => "test-model" }
    end

    # ActionCable::Channel::TestCase provides broadcasts for the current stream
    data = broadcasts("agent_hub_channel_test_agent").last
    data = JSON.parse(data) if data.is_a?(String)
    assert_equal "confirmation_bubble", data["type"]
    assert_match /Approve Now/, data["html"]
  end

  test "confirm_action broadcasts success" do
    user = User.create!(email: "admin7@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"

    # Broadcasts:
    # 1. 'confirmed' in confirm_action
    # 2. 'token' (Artifact created)
    # 3. 'token' (Handoff notification) - NEW
    # 4. 'token' (Artifact moved)
    assert_broadcasts("agent_hub_channel_test_agent", 4) do
      perform :confirm_action, { "message_id" => "cmd-123", "command" => "approve" }
    end
  end
  test "speak processes a backlog command" do
    user = User.create!(email: "admin8@example.com", password: "password", roles: [ "admin" ])
    stub_connection current_user: user
    subscribe agent_id: "test_agent"

    # We expect 1 broadcast to the specific agent stream
    assert_broadcasts("agent_hub_channel_test_agent", 1) do
      perform :speak, { "content" => "/backlog My New Feature", "model" => "test-model" }
    end

    data = broadcasts("agent_hub_channel_test_agent").last
    data = JSON.parse(data) if data.is_a?(String)
    assert_equal "token", data["type"]
    assert_match /Successfully added to backlog: My New Feature/, data["token"]

    # It now creates an Artifact instead of a BacklogItem
    assert_equal 1, Artifact.where(name: "My New Feature").count
  end

  test "handle_inspect_command displays artifact with micro_tasks" do
    user = User.create!(email: "admin9@example.com", password: "password", roles: [ "admin" ])
    artifact = Artifact.create!(
      name: "Test Inspect",
      artifact_type: "feature",
      payload: {
        "content" => "PRD Content",
        "micro_tasks" => [ { "id" => "task-01", "title" => "Micro Task 1", "estimate" => "20m" } ]
      }
    )
    AiWorkflowRun.create!(user: user, status: "draft", metadata: { "active_artifact_id" => artifact.id })

    stub_connection current_user: user
    subscribe agent_id: "test_agent"

    # Expect 2 broadcasts: token and message_finished
    assert_broadcasts("agent_hub_channel_test_agent", 2) do
      perform :speak, { "content" => "/inspect" }
    end

    all_broadcasts = broadcasts("agent_hub_channel_test_agent").map { |b| b.is_a?(String) ? JSON.parse(b) : b }
    data = all_broadcasts.find { |b| b["type"] == "token" }

    assert data, "Should have found a token broadcast"
    assert_equal "token", data["type"]
    assert_match /### 🔍 Inspecting Artifact: Test Inspect/, data["token"]
    assert_match /Micro Task 1/, data["token"]
  end

  test "confirm_action with explicit artifact_id uses that artifact" do
    user = User.create!(email: "admin_explicit@example.com", password: "password", roles: [ "admin" ])
    artifact = Artifact.create!(name: "Target Artifact", artifact_type: "feature", phase: "backlog", owner_persona: "SAP")

    stub_connection current_user: user
    subscribe agent_id: "sap-agent"

    # Expect 3 broadcasts: confirmed, handoff notification, and artifact moved
    assert_broadcasts("agent_hub_channel_sap-agent", 3) do
      perform :confirm_action, {
        "message_id" => "cmd-456",
        "command" => "approve",
        "artifact_id" => artifact.id
      }
    end

    artifact.reload
    assert_equal "ready_for_analysis", artifact.phase

    # Verify no new artifacts were created
    assert_equal 1, Artifact.where(name: "Target Artifact").count
    assert_equal 0, Artifact.where(name: "New Feature").count
  end

  test "confirm_action fallback finds sap_run even with -agent suffix" do
    user = User.create!(email: "admin_suffix@example.com", password: "password", roles: [ "admin" ])
    # Create sap_run with base name 'sap'
    sap_run = SapRun.create_conversation(user_id: user.id, persona_id: "sap", title: "My Cool Feature")
    artifact = Artifact.create!(name: "My Cool Feature", artifact_type: "feature", phase: "backlog", owner_persona: "SAP")
    sap_run.update!(artifact_id: artifact.id)

    stub_connection current_user: user
    subscribe agent_id: "sap-agent" # Subscription uses -agent suffix

    # We don't pass artifact_id, so it should use fallback
    perform :confirm_action, {
      "message_id" => "cmd-789",
      "command" => "approve"
    }

    artifact.reload
    assert_equal "ready_for_analysis", artifact.phase
    assert_equal 0, Artifact.where(name: "New Feature").count
  end

  test "confirm_action injects system message" do
    user = User.create!(email: "admin_system@example.com", password: "password", roles: [ "admin" ])
    sap_run = SapRun.create_conversation(user_id: user.id, persona_id: "sap", title: "System Msg Test")
    artifact = Artifact.create!(name: "System Msg Test", artifact_type: "feature", phase: "backlog", owner_persona: "SAP")
    sap_run.update!(artifact_id: artifact.id)

    stub_connection current_user: user
    subscribe agent_id: "sap-agent"

    perform :confirm_action, {
      "message_id" => "cmd-111",
      "command" => "approve",
      "artifact_id" => artifact.id
    }

    assert_equal "ready_for_analysis", artifact.reload.phase
    assert sap_run.sap_messages.system_role.exists?
    assert_equal "[SYSTEM: Phase changed to Ready For Analysis]", sap_run.sap_messages.system_role.last.content
  end

  test "confirm_action with finalize_prd updates the artifact" do
    user = User.create!(email: "admin_finalize@example.com", password: "password", roles: [ "admin" ])
    sap_run = SapRun.create_conversation(user_id: user.id, persona_id: "sap", title: "Finalize Test")
    artifact = Artifact.create!(name: "Finalize Test", artifact_type: "feature", phase: "backlog", owner_persona: "SAP")
    sap_run.update!(artifact_id: artifact.id)

    stub_connection current_user: user
    subscribe agent_id: "sap-agent"

    perform :confirm_action, {
      "message_id" => "cmd-222",
      "command" => "finalize_prd",
      "artifact_id" => artifact.id
    }

    artifact.reload
    assert_equal "in_analysis", artifact.phase, "Artifact should have moved to in_analysis phase"
  end

  test "confirm_action with finalize_prd creates a NEW artifact if none exists" do
    user = User.create!(email: "admin_new_final@example.com", password: "password", roles: [ "admin" ])
    sap_run = SapRun.create_conversation(user_id: user.id, persona_id: "sap", title: "Brand New Feature")
    sap_run.sap_messages.create!(role: :user, content: "Draft a PRD for X")
    sap_run.sap_messages.create!(role: :assistant, content: "Here is the PRD for X")

    stub_connection current_user: user
    subscribe agent_id: "sap-agent"

    assert_difference "Artifact.count", 1 do
      perform :confirm_action, {
        "message_id" => "cmd-333",
        "command" => "finalize_prd"
      }
    end

    artifact = Artifact.last
    assert_equal "Brand New Feature", artifact.name
    assert_equal "in_analysis", artifact.phase
    assert_equal sap_run.id, artifact.sap_runs.first.id if artifact.respond_to?(:sap_runs)
    # Check if sap_run was updated
    sap_run.reload
    assert_equal artifact.id, sap_run.artifact_id
  end
end
