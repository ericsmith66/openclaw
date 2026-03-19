module AgentHub
  class WorkflowBridge
    # Registry of valid intents
    # Maps Intent Name -> { label, action (for artifact transition), human_in_loop, color_class }
    REGISTRY = {
      "MOVE_TO_ANALYSIS" => { label: "Move to Analysis", action: "move_to_analysis", human_in_loop: true, color: "btn-success" },
      "FINALIZE_PRD" => { label: "Finalize PRD", action: "finalize_prd", human_in_loop: true, color: "btn-success" },
      "START_PLANNING" => { label: "Start Planning", action: "start_planning", human_in_loop: true, color: "btn-success" },
      "APPROVE_PLAN" => { label: "Approve Plan", action: "approve_plan", human_in_loop: true, color: "btn-success" },
      "START_IMPLEMENTATION" => { label: "Start Implementation", action: "start_implementation", human_in_loop: true, color: "btn-success" },
      "SAVE_TO_BACKLOG" => { label: "Save to Backlog", action: "backlog", human_in_loop: true, color: "btn-secondary" },

      # Compatibility Aliases
      "APPROVE_PRD" => { label: "Finalize PRD", action: "finalize_prd", human_in_loop: true, color: "btn-success" },
      "READY_FOR_DEV" => { label: "Approve Plan", action: "approve_plan", human_in_loop: true, color: "btn-success" },
      "START_DEV" => { label: "Start Implementation", action: "start_implementation", human_in_loop: true, color: "btn-success" },
      "BACKLOG" => { label: "Save to Backlog", action: "backlog", human_in_loop: true, color: "btn-secondary" },

      "COMPLETE_DEV" => { label: "Complete Dev", action: "approve", human_in_loop: true, color: "btn-success" },
      "APPROVE_QA" => { label: "Approve QA", action: "approve", human_in_loop: true, color: "btn-success" },
      "REJECT" => { label: "Reject/Rework", action: "reject", human_in_loop: true, color: "btn-warning" },
      "START_BUILD" => { label: "Start Build", action: "approve", human_in_loop: false, color: "btn-info" },
      "APPROVE_ARTIFACT" => { label: "Approve Now", action: "approve", human_in_loop: true, color: "btn-success" }
    }.freeze

    TAG_PATTERN = /\[?ACTION: ([A-Z0-9_]+): (\d+)\]?/

    def self.parse(content, role: "assistant", conversation: nil)
      # Tag Collision Mitigation: Only scan messages where role: assistant
      return [] unless role == "assistant" || role == :assistant

      intents = []
      content.scan(TAG_PATTERN) do |intent_name, id|
        config = REGISTRY[intent_name]
        if config
          intents << {
            intent: intent_name,
            id: id,
            config: config
          }

          # Link conversation to artifact
          if conversation && conversation.respond_to?(:artifact_id=)
            begin
              conversation.update!(artifact_id: id) if conversation.artifact_id != id.to_i
            rescue ActiveRecord::UnknownAttributeError
              Rails.logger.warn("[AgentHub::WorkflowBridge] SapRun does not have artifact_id yet.")
            end
          end
        else
          Rails.logger.warn("[AgentHub::WorkflowBridge] Detected unknown intent: #{intent_name} (Hallucination?)")
        end
      end
      intents
    end

    def self.execute_transition(artifact_id: nil, command:, user:, agent_id:, rag_request_id: nil, payload_updates: {}, silent: false)
      # 1. Resolve Artifact
      artifact = if artifact_id.to_s.strip.present?
        Artifact.find_by(id: artifact_id)
      else
        sap_run = SapRun.for_user_and_persona(user.id, agent_id).first
        linked_artifact_id = sap_run&.artifact_id

        if linked_artifact_id
          Artifact.find_by(id: linked_artifact_id)
        else
          run = AiWorkflowRun.for_user(user).active.order(updated_at: :desc).first
          run&.active_artifact
        end
      end

      # 2. Create Artifact if missing and command is an initiating one
      initiating_commands = %w[approve finalize_prd move_to_analysis]
      if !artifact && initiating_commands.include?(command)
        sap_run = SapRun.for_user_and_persona(user.id, agent_id).first
        artifact_name = sap_run&.title || "New Feature"
        artifact_content = sap_run&.sap_messages&.order(:created_at)&.last&.content || "Proposed feature from conversation."

        artifact = Artifact.create!(
          name: artifact_name,
          artifact_type: "feature",
          phase: "backlog",
          owner_persona: "SAP",
          payload: { "content" => artifact_content }
        )

        sap_run&.update!(artifact_id: artifact.id)

        # System Message for new artifact
        if sap_run
          system_msg = "[SYSTEM: Phase changed to Backlog]"
          sap_run.sap_messages.create!(role: :system, content: system_msg)
          AgentHubChannel.broadcast_system_message(agent_id: agent_id, text: system_msg)
        end

        AiWorkflowRun.create!(
          user: user,
          status: "draft",
          metadata: { "active_artifact_id" => artifact.id, "title" => "Workflow for #{artifact_name}" }
        )

        broadcast_artifact_update(artifact, user: user)
        unless silent
          broadcast_token(agent_id, "New Artifact '#{artifact.name}' created and added to backlog. Assigned to: SAP.")
        end
      end

      return nil unless artifact

      # 3. Apply payload updates (e.g. implementation notes, micro-tasks)
      if payload_updates.blank? && %w[start_planning approve_plan].include?(command)
        sap_run = SapRun.for_user_and_persona(user.id, agent_id).first
        last_msg = sap_run&.sap_messages&.assistant_role&.order(:created_at)&.last&.content
        if last_msg.present?
          # Strip the action tag for cleaner implementation notes
          last_msg = last_msg.gsub(TAG_PATTERN, "").strip
          payload_updates = { "implementation_notes" => last_msg }
        end
      end

      if payload_updates.present?
        artifact.payload ||= {}
        artifact.payload.merge!(payload_updates)
      end

      # 4. Ensure AiWorkflowRun exists
      run = AiWorkflowRun.find_or_create_by!(user: user, status: "draft") do |r|
        r.metadata = { "active_artifact_id" => artifact.id, "title" => "Workflow for #{artifact.name}" }
      end
      if run.active_artifact_id.to_s != artifact.id.to_s
        run.update!(metadata: run.metadata.merge("active_artifact_id" => artifact.id))
      end

      # 5. Execute transition
      rag_id = rag_request_id || (sap_run&.output_json || {})["last_rag_request_id"]

      if artifact.transition_to(command, agent_id, rag_request_id: rag_id)
        # 6. Post-transition side effects
        broadcast_artifact_update(artifact, user: user)

        # 7. Trigger notification/action from new owner (PRD-AH-011B/E improvement)
        trigger_owner_notification(artifact, user: user, current_agent_id: agent_id)

        # Persist phase-change system message after any owner notification so the
        # system marker remains the most recent entry in the conversation.
        sap_run = SapRun.for_user_and_persona(user.id, agent_id).first
        if sap_run
          system_msg = "[SYSTEM: Phase changed to #{artifact.phase.humanize.titleize}]"
          sap_run.sap_messages.create!(role: :system, content: system_msg)
          AgentHubChannel.broadcast_system_message(agent_id: agent_id, text: system_msg)
        end

        unless silent
          broadcast_token(agent_id, "Artifact '#{artifact.name}' moved to phase: #{artifact.phase.humanize}. Assigned to: #{artifact.owner_persona}.")
        end

        Rails.logger.info("[AgentHub::WorkflowBridge] Transitioned artifact #{artifact.id} to #{artifact.phase} via #{command}")
      else
        unless silent
          broadcast_token(agent_id, "Failed to transition artifact '#{artifact.name}' from phase: #{artifact.phase.humanize}.")
        end
      end

      artifact
    end

    def self.trigger_owner_notification(artifact, user:, current_agent_id:)
      return unless artifact && user

      target_persona = artifact.owner_persona
      target_agent_id = case target_persona
      when "SAP" then "sap-agent"
      when "Coordinator" then "coordinator-agent"
      when "CWA" then "cwa-agent"
      else nil
      end

      return unless target_agent_id

      # If the owner changed, have the new agent "speak" or at least notify.
      # For now, we'll send a system-generated message from that agent's persona.
      message = case artifact.phase
      when "ready_for_analysis" then "I've received '#{artifact.name}' in the backlog. I'll review it soon."
      when "in_analysis" then "I'm starting the analysis for '#{artifact.name}'. I'll let you know when I have a technical proposal."
      when "planning" then "I'm working on the technical plan for '#{artifact.name}'."
      when "in_development" then "I've started implementing '#{artifact.name}'. I'll notify you when the build is ready for QA."
      when "ready_for_qa" then "Implementation of '#{artifact.name}' is complete. I'm ready for your review."
      when "complete" then "Artifact '#{artifact.name}' is now finalized. Great work!"
      else nil
      end

      return unless message

      # Broadcast to BOTH the current agent (so the user sees it immediately)
      # and the target agent (so it's in their history).
      [ current_agent_id, target_agent_id ].uniq.each do |aid|
        ActionCable.server.broadcast("agent_hub_channel_#{aid}", {
          type: "token",
          message_id: "handoff-#{Time.now.to_i}",
          token: "\n\n**#{target_persona}**: #{message}"
        })
      end

      # Persist the message in the target agent's run
      run = SapRun.for_user_and_persona(user.id, target_agent_id).first
      if run
        run.sap_messages.create!(role: :assistant, content: message)
      end
    end

    def self.broadcast_artifact_update(artifact, user: nil)
      return unless artifact

      # Broadcast to artifact-specific stream
      Turbo::StreamsChannel.broadcast_replace_to(
        "artifact_#{artifact.id}",
        target: "artifact-preview-container",
        html: ApplicationController.render(ArtifactPreviewComponent.new(artifact: artifact, user_id: user&.id), layout: false)
      )

      # Broadcast to global user stream if user provided (to handle new artifacts appearing in empty sidebars)
      if user
        Turbo::StreamsChannel.broadcast_replace_to(
          "active_artifacts_user_#{user.id}",
          target: "artifact-preview-container",
          html: ApplicationController.render(ArtifactPreviewComponent.new(artifact: artifact, user_id: user.id), layout: false)
        )
      end
    end

    private

    def self.broadcast_token(agent_id, token)
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: "res-#{Time.now.to_i}",
        token: token
      })
    end
  end
end
