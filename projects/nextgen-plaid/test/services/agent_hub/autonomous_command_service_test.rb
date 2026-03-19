require "test_helper"

class AgentHub::AutonomousCommandServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test_auto_#{rand(1000)}@example.com", password: "password")
    @broadcasts = []
    @callback = proc { |agent_id, payload| @broadcasts << { agent_id: agent_id, payload: payload } }
    @service = AgentHub::AutonomousCommandService.new(user: @user, broadcast_callback: @callback)
  end

  test "call with no artifact should broadcast error" do
    # Assuming AiWorkflowRun.for_user(@user).active returns empty
    @service.call({ command: "spike" }, "agent_1")

    assert @broadcasts.any? { |b| b[:payload][:token].include?("No active artifact") }
  end

  test "call with artifact should launch workflow" do
    run = AiWorkflowRun.create!(user: @user, status: "pending", correlation_id: "test-run", metadata: {})
    artifact = Artifact.create!(name: "Test Artifact", artifact_type: "prd", phase: "backlog", payload: { "content" => "Some PRD" })
    run.update!(metadata: { "active_artifact_id" => artifact.id })

    # Mock WorkflowBridge and AiWorkflowService
    AgentHub::WorkflowBridge.stub :execute_transition, true do
      AiWorkflowService.stub :run, true do
        # We need to wait for the thread if we want to verify the completion broadcast,
        # but for unit test we can just verify the initial broadcast.
        @service.call({ command: "spike" }, "agent_1")
      end
    end

    assert @broadcasts.any? { |b| b[:payload][:token].include?("Launching autonomous spike") }
  end
end
