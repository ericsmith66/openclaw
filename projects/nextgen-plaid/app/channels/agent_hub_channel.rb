class AgentHubChannel < ApplicationCable::Channel
  MAX_STREAMS = 5

  def self.broadcast_system_message(agent_id:, text:)
    ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
      type: "system",
      content: text
    })
  end

  def subscribed
    unless current_user&.admin?
      reject
      Rails.logger.warn(JSON.generate({ event: "agent_hub_channel_rejected", reason: "unauthorized", user_id: current_user&.id }))
      return
    end

    active_streams = Rails.cache.read("agent_hub_active_streams").to_i

    if active_streams >= MAX_STREAMS
      reject
      Rails.logger.warn(JSON.generate({ event: "agent_hub_channel_rejected", reason: "max_streams_reached" }))
      return
    end

    Rails.cache.write("agent_hub_active_streams", active_streams + 1)
    stream_from "agent_hub_channel_#{params[:agent_id]}"
    stream_from "agent_hub_channel_all_agents" # For sidebar updates
    stream_from "agent_hub_channel_workflow_monitor" # For inter-agent monitor
    Rails.logger.info(JSON.generate({ event: "agent_hub_channel_subscribed", agent_id: params[:agent_id] }))
  end

  def unsubscribed
    active_streams = Rails.cache.read("agent_hub_active_streams") || 1
    Rails.cache.write("agent_hub_active_streams", [ active_streams - 1, 0 ].max)
    Rails.logger.info(JSON.generate({ event: "agent_hub_channel_unsubscribed", agent_id: params[:agent_id] }))
  end

  def interrogate(data)
    # This method is called from the client
    # It broadcasts a request to the client to send back its state
    request_id = data["request_id"]
    @interrogation_started_at ||= {}
    @interrogation_started_at[request_id] = Time.current

    ActionCable.server.broadcast("agent_hub_channel_#{params[:agent_id]}", { type: "interrogation_request", request_id: request_id })
    Rails.logger.info(JSON.generate({ event: "interrogation_requested", agent_id: params[:agent_id], request_id: request_id }))
  end

  def report_state(data)
    # This method receives the state from the client
    request_id = data["request_id"]

    # Calculate latency
    started_at = @interrogation_started_at&.delete(request_id)
    latency_ms = started_at ? ((Time.current - started_at) * 1000).round : nil

    log_payload = {
      event: "interrogation_report",
      agent_id: params[:agent_id],
      request_id: request_id,
      latency_ms: latency_ms,
      dom_preview: data["dom"]&.slice(0, 100),
      console: data["console"]
    }

    # We output to stdout as well in development to make it visible in the console if attached
    puts "\n[AgentHubChannel] INTERROGATION REPORT RECEIVED: #{request_id} (Latency: #{latency_ms}ms)\n" if Rails.env.development?

    Rails.logger.info(JSON.generate(log_payload))

    if latency_ms
      Rails.logger.info(JSON.generate({
        event: "interrogation_latency",
        agent_id: params[:agent_id],
        request_id: request_id,
        ms: latency_ms
      }))
    end
  end

  def confirm_action(data)
    message_id = data["message_id"]
    command = data["command"]
    label = data["label"]
    artifact_id = data["artifact_id"]
    agent_id = params[:agent_id]

    Rails.logger.info(JSON.generate({ event: "command_confirmed", agent_id: agent_id, message_id: message_id, command: command, label: label, artifact_id: artifact_id }))

    # Broadcast success immediately to stop UI spinner
    ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
      type: "confirmed",
      message_id: message_id
    })

    # Execute artifact transition if applicable
    valid_actions = %w[approve reject backlog finalize_prd move_to_analysis start_planning approve_plan start_implementation]
    if valid_actions.include?(command)
      AgentHub::WorkflowBridge.execute_transition(
        artifact_id: artifact_id,
        command: command,
        user: current_user,
        agent_id: agent_id
      )
      return
    end

    # Broadcast the result of the command
    ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
      type: "token",
      message_id: "res-#{Time.now.to_i}",
      token: "Action executed: #{command} has been processed successfully."
    })
  end

  def speak(data)
    content = data["content"]
    model = data["model"]
    attachment_ids = data["attachment_ids"] || []
    conversation_id = data["conversation_id"]
    original_agent_id = params[:agent_id]

    Rails.logger.info(JSON.generate({
      event: "agent_hub_message_received",
      agent_id: original_agent_id,
      content: content,
      model: model,
      attachment_ids: attachment_ids,
      conversation_id: conversation_id
    }))

    # 1. Parse for mentions (PRD-AH-008B)
    mention_data = AgentHub::MentionParser.call(content)

    if mention_data
      target_agent_id = mention_data[:agent_id]
      content = mention_data[:clean_content]
      Rails.logger.info(JSON.generate({ event: "mention_detected", target_agent_id: target_agent_id }))
    else
      target_agent_id = original_agent_id
    end

    # 2. Parse for commands
    command = AgentHub::CommandParser.call(content)

    if command
      if command[:type] == :backlog
        handle_backlog_command(command, target_agent_id)
      elsif command[:command] == "spike" || command[:command] == "plan"
        AgentHub::AutonomousCommandService.new(
          user: current_user,
          broadcast_callback: method(:broadcast_to_channel)
        ).call(command, target_agent_id)
      else
        AgentHub::CommandExecutor.new(
          user: current_user,
          broadcast_callback: method(:broadcast_to_channel)
        ).call(command, target_agent_id)
      end
    else
      # 3. Regular AI chat (routed to target_agent_id if mention exists, else original)
      handle_chat_v2(content, model, target_agent_id, original_agent_id, conversation_id)
    end
  end

  private

  def broadcast_to_channel(agent_id, payload)
    ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", payload)
  end

  def handle_chat_v2(content, model, target_agent_id, client_agent_id, conversation_id)
    client_agent_id ||= target_agent_id

    # Find or create a SapRun for this conversation
    sap_run = if conversation_id
      SapRun.find_by(id: conversation_id, user_id: current_user.id)
    else
      correlation_id = "agent-hub-#{target_agent_id}-#{current_user.id}"
      SapRun.find_by(correlation_id: correlation_id, user_id: current_user.id) ||
        SapRun.create_conversation(user_id: current_user.id, persona_id: target_agent_id)
    end

    Thread.new do
      begin
        result = AgentHub::ChatHandler.new(
          user: current_user,
          sap_run: sap_run,
          broadcast_callback: method(:broadcast_to_channel)
        ).call(
          content: content,
          model: model,
          target_agent_id: target_agent_id,
          client_agent_id: client_agent_id
        )

        if result[:status] == :ok && result[:intents].present?
          process_workflow_intents(result[:intents], result[:message_id], result[:assistant_message], client_agent_id, target_agent_id)
        end
      rescue StandardError => e
        Rails.logger.error("Error in handle_chat_v2: #{e.message}\n#{e.backtrace.join("\n")}")
        broadcast_to_channel(client_agent_id, {
          type: "token",
          message_id: "err-#{Time.now.to_i}",
          token: "Sorry, I encountered an error: #{e.message}"
        })
      end
    end
  end

  def process_workflow_intents(intents, message_id, _assistant_message, client_agent_id, target_agent_id)
    intents.each_with_index do |intent_data, index|
      intent_name = intent_data[:intent]
      artifact_id = intent_data[:id]
      config = intent_data[:config]

      Rails.logger.info("[AgentHubChannel] WorkflowBridge detected intent: #{intent_name} for artifact: #{artifact_id}")

      if config[:human_in_loop]
        bubble_id = "#{message_id}-cb-#{index}"
        broadcast_confirmation(client_agent_id, bubble_id, config[:action], config[:color], config[:label], artifact_id)
      else
        AgentHub::WorkflowBridge.execute_transition(
          artifact_id: artifact_id,
          command: config[:action],
          user: current_user,
          agent_id: target_agent_id,
          silent: true
        )

        broadcast_to_channel(client_agent_id, {
          type: "token",
          message_id: "silent-#{Time.now.to_i}",
          token: "\n\n⚡ **[System Notification]**: Automated action `#{intent_name}` executed."
        })
      end
    end
  end

  def handle_backlog_command(command_data, agent_id)
    args = command_data[:args]
    message_id = "backlog-#{Time.now.to_i}"

    begin
      item = AgentHub::BacklogService.call(
        user: current_user,
        content: args || "Empty Backlog Item",
        metadata: { source: "agent_hub", agent_id: agent_id }
      )

      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: "Successfully added to backlog: #{item.respond_to?(:title) ? item.title : item.name} (ID: #{item.id})"
      })
    rescue StandardError => e
      Rails.logger.error("Error adding to backlog: #{e.message}")
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: "Failed to add to backlog: #{e.message}"
      })
    end
  end

  def handle_command_legacy(command_data, agent_id)
    cmd = command_data[:command]
    args = command_data[:args]
    message_id = "cmd-#{Time.now.to_i}"

    case cmd
    when "approve"
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: "legacy-#{Time.now.to_i}",
        token: "⚠️ [Legacy]: Slash commands like `/approve` are deprecated. Please use the agent-triggered confirmation buttons."
      })
      broadcast_confirmation(agent_id, message_id, cmd, "btn-success", "Approve Now")
    when "reject"
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: "legacy-#{Time.now.to_i}",
        token: "⚠️ [Legacy]: Slash commands like `/reject` are deprecated."
      })
      broadcast_confirmation(agent_id, message_id, cmd, "btn-warning", "Reject/Rework")
    when "backlog"
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: "legacy-#{Time.now.to_i}",
        token: "⚠️ [Legacy]: Slash commands like `/backlog` are deprecated."
      })
      broadcast_confirmation(agent_id, message_id, cmd, "btn-secondary", "Move to Backlog")
    when "handoff"
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: "legacy-#{Time.now.to_i}",
        token: "⚠️ [Legacy]: Slash commands like `/handoff` are deprecated."
      })
      broadcast_confirmation(agent_id, message_id, cmd, "btn-warning", "Confirm Handoff")
    when "delete"
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: "legacy-#{Time.now.to_i}",
        token: "⚠️ [Legacy]: Slash commands like `/delete` are deprecated."
      })
      broadcast_confirmation(agent_id, message_id, cmd, "btn-error", "Confirm Delete")
    when "inspect"
      handle_inspect_command_legacy(agent_id)
    when "save"
      handle_save_command_legacy(args, agent_id)
    else
      # For other commands, just broadcast that command was recognized
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: "Command recognized: #{cmd} with args: #{args}"
      })
    end
  end

  def handle_inspect_command_legacy(agent_id)
    run = AiWorkflowRun.for_user(current_user).active.order(updated_at: :desc).first
    artifact = run&.active_artifact
    message_id = "inspect-#{Time.now.to_i}"

    if artifact
      content = artifact.payload["content"] || "No content"
      phase = artifact.phase.humanize
      owner = artifact.owner_persona
      micro_tasks = artifact.payload["micro_tasks"]
      notes = artifact.payload["implementation_notes"]

      formatted_message = <<~TEXT
        ### 🔍 Inspecting Artifact: #{artifact.name}
        **Phase:** #{phase}
        **Owner:** #{owner}
        **Type:** #{artifact.artifact_type}

        ---
        **PRD Content:**
        #{content}
      TEXT

      if micro_tasks.present?
        formatted_message << "\n\n---\n**📋 Technical Plan (Micro-tasks):**\n"
        micro_tasks.each do |task|
          formatted_message << "- [ ] **#{task['id']}**: #{task['title']} (#{task['estimate']})\n"
        end
      end

      if notes.present?
        formatted_message << "\n\n---\n**📝 Implementation Notes:**\n#{notes}"
      end

      formatted_message << <<~TEXT


        ---
        **Audit Trail:**
        #{artifact.payload["audit_trail"]&.last(3)&.map { |e| "- #{e['timestamp']}: #{e['from_phase']} -> #{e['to_phase']} (#{e['action']})" }&.join("\n")}
      TEXT

      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: formatted_message
      })

      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "message_finished",
        message_id: message_id,
        content_html: Ai::MarkdownRenderer.render(formatted_message)
      })
    else
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: "No active artifact found to inspect."
      })
    end
  end

  def handle_save_command_legacy(args, agent_id)
    run = AiWorkflowRun.for_user(current_user).active.order(updated_at: :desc).first
    artifact = run&.active_artifact
    message_id = "save-#{Time.now.to_i}"

    if artifact
      if args.blank?
        ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
          type: "token",
          message_id: message_id,
          token: "Usage: `/save <new content>` to update the artifact's PRD content."
        })
        return
      end

      artifact.payload["content"] = args
      artifact.save!

      # Broadcast update to the Preview Sidebar
      AgentHub::WorkflowBridge.broadcast_artifact_update(artifact)

      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: "✅ Artifact '#{artifact.name}' updated and saved successfully."
      })
    else
      ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
        type: "token",
        message_id: message_id,
        token: "No active artifact found to save."
      })
    end
  end

  def broadcast_confirmation(agent_id, message_id, command, color_class, label, artifact_id = nil)
    html = ApplicationController.render(
      ConfirmationBubbleComponent.new(
        message_id: message_id,
        command: command,
        color_class: color_class,
        label: label,
        artifact_id: artifact_id
      ),
      layout: false
    )

    ActionCable.server.broadcast("agent_hub_channel_#{agent_id}", {
      type: "confirmation_bubble",
      message_id: message_id,
      html: html
    })
  end

  def handle_chat_legacy(content, model, target_agent_id, client_agent_id = nil, conversation_id = nil)
    client_agent_id ||= target_agent_id

    Rails.logger.info("[handle_chat] Received conversation_id: #{conversation_id == nil ? 'nil' : conversation_id.to_s}, user_id: #{current_user.id}")

    # Start typing indicator on both target and client channels
    ActionCable.server.broadcast("agent_hub_channel_#{target_agent_id}", { type: "typing", status: "start" })
    ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", { type: "typing", status: "start" }) if client_agent_id != target_agent_id

    Thread.new do
      begin
        # Generate unique message_id for this response
        message_id = "msg-#{Time.now.to_i}-#{rand(1000)}"

        # Find or create a SapRun for this conversation
        sap_run = if conversation_id
          SapRun.find_by(id: conversation_id, user_id: current_user.id)
        else
          # Legacy support: find by old correlation_id format or create new conversation
          correlation_id = "agent-hub-#{target_agent_id}-#{current_user.id}"
          existing_run = SapRun.find_by(correlation_id: correlation_id, user_id: current_user.id)

          if existing_run
            existing_run
          else
            SapRun.create_conversation(user_id: current_user.id, persona_id: target_agent_id)
          end
        end

        Rails.logger.info("[handle_chat] Using sap_run_id: #{sap_run&.id}, title: #{sap_run&.title}")

        # Update status if needed
        sap_run.update!(status: :running, started_at: Time.current) if sap_run.pending_status?

        # Auto-generate title from first message if still "New Conversation"
        sap_run.generate_title_from_first_message if sap_run.sap_messages.user_role.count == 0

        # Build RAG context using RagProvider
        rag_context = SapAgent::RagProvider.build_prefix("default", current_user.id, target_agent_id, sap_run.id)

        # Build messages array with context and conversation history
        messages = []

        # Add system message with RAG context and persona
        messages << {
          role: "system",
          content: "You are #{target_agent_id.upcase}. #{rag_context}"
        }

        # Load conversation history from SapMessages
        sap_run.sap_messages.order(:created_at).each do |msg|
          messages << { role: msg.role, content: msg.content }
        end

        # Add the new user message
        messages << { role: "user", content: content }

        # Save the user message to the database
        sap_run.sap_messages.create!(role: :user, content: content)

        # Create assistant message placeholder
        sap_run.reload
        rag_request_id = (sap_run.output_json || {})["last_rag_request_id"]
        assistant_message = sap_run.sap_messages.create!(role: :assistant, content: "", rag_request_id: rag_request_id, model: model)

        # Send to SmartProxyClient with full context
        client = AgentHub::SmartProxyClient.new(model: model, stream: true)

        # We broadcast to the target_agent_id channel
        # If there was a mention, the client is subscribed to THEIR agent_id channel,
        # but they might also need to see the response if they are on a different tab.
        # PRD says: "The assistant's response bubble reflects the mentioned persona."
        # This implies the response should appear in the CURRENT tab.

        response = client.chat(messages, stream_to: client_agent_id, message_id: message_id)

        # Update assistant message with full response (or fail gracefully)
        if response.is_a?(Hash) && (response["error"].present? || response[:error].present?)
          error_message = (response["error"] || response[:error]).to_s
          error_message = "Sorry, I couldn't get a response from the model. Please try again." if error_message.blank?

          assistant_message.update!(content: error_message)
          ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", {
            type: "token",
            message_id: message_id,
            token: error_message
          })
        elsif response && (response["choices"] || response[:choices])
          full_content = (response.dig("choices", 0, "message", "content") || response.dig(:choices, 0, :message, :content))
          if full_content.present?
            assistant_message.update!(content: full_content)

            # Broadcast that the message is finished with rendered HTML
            ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", {
              type: "message_finished",
              message_id: message_id,
              content_html: Ai::MarkdownRenderer.render(full_content),
              rag_request_id: rag_request_id
            })

            # Workflow Bridge Action Detection (PRD-AH-011B)
            intents = AgentHub::WorkflowBridge.parse(full_content, role: "assistant", conversation: sap_run)
            intents.each_with_index do |intent_data, index|
              intent_name = intent_data[:intent]
              artifact_id = intent_data[:id]
              config = intent_data[:config]

              Rails.logger.info("[AgentHubChannel] WorkflowBridge detected intent: #{intent_name} for artifact: #{artifact_id}")

              if config[:human_in_loop]
                # Use a unique ID for each confirmation bubble to avoid DOM ID collisions (PRD-AH-011B fix)
                bubble_id = "#{message_id}-cb-#{index}"
                broadcast_confirmation(client_agent_id, bubble_id, config[:action], config[:color], config[:label], artifact_id)
              else
                # Silent Action: Automate backend state changes via Bridge
                AgentHub::WorkflowBridge.execute_transition(
                  artifact_id: artifact_id,
                  command: config[:action],
                  user: current_user,
                  agent_id: target_agent_id,
                  silent: true
                )

                # Provide execution feedback as a notification token (manual feedback here to match previous behavior)
                ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", {
                  type: "token",
                  message_id: "silent-#{Time.now.to_i}",
                  token: "\n\n⚡ **[System Notification]**: Automated action `#{intent_name}` executed."
                })
              end
            end
          else
            error_message = "Sorry, I couldn't get a response from the model. Please try again."
            assistant_message.update!(content: error_message)
            ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", {
              type: "token",
              message_id: message_id,
              token: error_message
            })
          end
        else
          error_message = "Sorry, I couldn't get a response from the model. Please try again."
          assistant_message.update!(content: error_message)
          ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", {
            type: "token",
            message_id: message_id,
            token: error_message
          })
        end
      rescue StandardError => e
        Rails.logger.error("Error in handle_chat: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", {
          type: "token",
          message_id: message_id,
          token: "Sorry, I encountered an error: #{e.message}"
        })
      ensure
        Rails.logger.info("[handle_chat] Ensuring typing stop for target: #{target_agent_id}, client: #{client_agent_id}")
        ActionCable.server.broadcast("agent_hub_channel_#{target_agent_id}", { type: "typing", status: "stop" })
        ActionCable.server.broadcast("agent_hub_channel_#{client_agent_id}", { type: "typing", status: "stop" }) if client_agent_id != target_agent_id
      end
    end
  end
end
