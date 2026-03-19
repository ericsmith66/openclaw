module AgentHub
  # Handles slash command execution and artifact operations for AgentHub.
  #
  # This class extracts command-handling logic from AgentHubChannel, including
  # artifact inspection, saving, and legacy command warnings.
  class CommandExecutor
    # @return [User] The user executing the command
    attr_reader :user
    # @return [Proc] Callback to broadcast messages to ActionCable
    attr_reader :broadcast_callback

    # Initializes the CommandExecutor.
    #
    # @param user [User] The user executing the command
    # @param broadcast_callback [Proc] Callback to broadcast messages to ActionCable
    def initialize(user:, broadcast_callback:)
      @user = user
      @broadcast_callback = broadcast_callback
    end

    # Executes a command.
    #
    # @param command_data [Hash] Data containing :command and :args
    # @param agent_id [String] The ID of the agent channel
    def call(command_data, agent_id)
      cmd = command_data[:command]
      args = command_data[:args]
      message_id = "cmd-#{Time.now.to_i}"

      case cmd
      when "approve", "reject", "backlog", "handoff", "delete"
        handle_deprecated_command(cmd, agent_id, message_id)
      when "inspect"
        handle_inspect_command(agent_id)
      when "save"
        handle_save_command(args, agent_id)
      else
        # For other commands, just broadcast that command was recognized
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: "Command recognized: #{cmd} with args: #{args}"
        })
      end
    end

    private

    def handle_deprecated_command(cmd, agent_id, message_id)
      labels = {
        "approve" => [ "btn-success", "Approve Now" ],
        "reject" => [ "btn-warning", "Reject/Rework" ],
        "backlog" => [ "btn-secondary", "Move to Backlog" ],
        "handoff" => [ "btn-warning", "Confirm Handoff" ],
        "delete" => [ "btn-error", "Confirm Delete" ]
      }
      css_class, label = labels[cmd]

      broadcast_callback.call(agent_id, {
        type: "token",
        message_id: "legacy-#{Time.now.to_i}",
        token: "⚠️ [Legacy]: Slash commands like `/#{cmd}` are deprecated. Please use the agent-triggered confirmation buttons."
      })
      broadcast_confirmation(agent_id, message_id, cmd, css_class, label)
    end

    def handle_inspect_command(agent_id)
      run = AiWorkflowRun.for_user(user).active.order(updated_at: :desc).first
      artifact = run&.active_artifact
      message_id = "inspect-#{Time.now.to_i}"

      if artifact
        formatted_message = build_inspect_message(artifact)
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: formatted_message
        })

        broadcast_callback.call(agent_id, {
          type: "message_finished",
          message_id: message_id,
          content_html: Ai::MarkdownRenderer.render(formatted_message)
        })
      else
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: "No active artifact found to inspect."
        })
      end
    end

    def build_inspect_message(artifact)
      content = artifact.payload["content"] || "No content"
      phase = artifact.phase.humanize
      owner = artifact.owner_persona
      micro_tasks = artifact.payload["micro_tasks"]
      notes = artifact.payload["implementation_notes"]

      message = <<~TEXT
        ### 🔍 Inspecting Artifact: #{artifact.name}
        **Phase:** #{phase}
        **Owner:** #{owner}
        **Type:** #{artifact.artifact_type}

        ---
        **PRD Content:**
        #{content}
      TEXT

      if micro_tasks.present?
        message << "\n\n---\n**📋 Technical Plan (Micro-tasks):**\n"
        micro_tasks.each do |task|
          message << "- [ ] **#{task['id']}**: #{task['title']} (#{task['estimate']})\n"
        end
      end

      if notes.present?
        message << "\n\n---\n**📝 Implementation Notes:**\n#{notes}"
      end

      message << <<~TEXT


        ---
        **Audit Trail:**
        #{artifact.payload["audit_trail"]&.last(3)&.map { |e| "- #{e['timestamp']}: #{e['from_phase']} -> #{e['to_phase']} (#{e['action']})" }&.join("\n")}
      TEXT
      message
    end

    def handle_save_command(args, agent_id)
      run = AiWorkflowRun.for_user(user).active.order(updated_at: :desc).first
      artifact = run&.active_artifact
      message_id = "save-#{Time.now.to_i}"

      if artifact
        artifact.payload["content"] = args
        artifact.save!
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: "✅ Artifact content updated and saved."
        })
      else
        broadcast_callback.call(agent_id, {
          type: "token",
          message_id: message_id,
          token: "❌ No active artifact found to save."
        })
      end
    end

    def broadcast_confirmation(agent_id, message_id, intent, css_class, label)
      html = ApplicationController.render(
        ConfirmationBubbleComponent.new(
          message_id: message_id,
          command: intent,
          color_class: css_class,
          label: label
        ),
        layout: false
      )

      broadcast_callback.call(agent_id, {
        type: "confirmation_bubble",
        message_id: message_id,
        html: html
      })
    end
  end
end
