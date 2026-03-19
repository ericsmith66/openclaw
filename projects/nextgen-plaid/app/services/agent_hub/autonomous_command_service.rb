module AgentHub
  # Handles complex autonomous operations like spikes and plans for AgentHub.
  #
  # This service manages the transition of artifacts into analysis phases and
  # triggers the AiWorkflowService to run autonomous loops.
  class AutonomousCommandService
    # @return [User] The user triggering the command
    attr_reader :user
    # @return [Proc] Callback to broadcast messages to ActionCable
    attr_reader :broadcast_callback

    # Initializes the AutonomousCommandService.
    #
    # @param user [User] The user triggering the command
    # @param broadcast_callback [Proc] Callback to broadcast messages to ActionCable
    def initialize(user:, broadcast_callback:)
      @user = user
      @broadcast_callback = broadcast_callback
    end

    # Executes an autonomous command.
    #
    # @param command_data [Hash] Data containing :command (spike/plan)
    # @param agent_id [String] The ID of the agent channel
    def call(command_data, agent_id)
      cmd = command_data[:command]
      message_id = "auto-#{Time.now.to_i}"

      run = AiWorkflowRun.for_user(user).active.order(updated_at: :desc).first
      artifact = run&.active_artifact

      unless artifact
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: "No active artifact linked to this run. Create or link an artifact first."
        })
        return
      end

      prd_content = artifact.payload["content"]
      if prd_content.blank?
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: "Active artifact '#{artifact.name}' has no content. Please provide a PRD first."
        })
        return
      end

      broadcast_callback.call(agent_id, {
        type: "token",
        message_id: message_id,
        token: "🚀 Launching autonomous #{cmd} for '#{artifact.name}'... The Coordinator will now review the PRD and generate a technical breakdown."
      })

      # Trigger phase transition if needed (Backlog -> Ready for Analysis -> In Analysis)
      ensure_artifact_in_analysis(artifact, agent_id)

      Thread.new do
        execute_autonomous_workflow(cmd, prd_content, run, artifact, agent_id)
      end
    end

    private

    def ensure_artifact_in_analysis(artifact, agent_id)
      if artifact.phase == "backlog"
        AgentHub::WorkflowBridge.execute_transition(artifact_id: artifact.id, command: "approve", user: user, agent_id: agent_id, silent: true)
        AgentHub::WorkflowBridge.execute_transition(artifact_id: artifact.id, command: "approve", user: user, agent_id: agent_id, silent: true)
      elsif artifact.phase == "ready_for_analysis"
        AgentHub::WorkflowBridge.execute_transition(artifact_id: artifact.id, command: "approve", user: user, agent_id: agent_id, silent: true)
      end
    end

    def execute_autonomous_workflow(cmd, prd_content, run, artifact, agent_id)
      begin
        # Ensure tools can execute for the spike/plan
        ENV["AI_TOOLS_EXECUTE"] = "true"

        AiWorkflowService.run(
          prompt: prd_content,
          correlation_id: run.id,
          model: ENV["AI_DEV_MODEL"]
        )

        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: "res-#{Time.now.to_i}",
          token: "✅ Autonomous #{cmd} completed for '#{artifact.name}'. Check the Workflow UI for details."
        })
      rescue => e
        Rails.logger.error("Autonomous command failed: #{e.message}")
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: "res-#{Time.now.to_i}",
          token: "❌ Autonomous #{cmd} failed: #{e.message}"
        })
      end
    end
  end
end
