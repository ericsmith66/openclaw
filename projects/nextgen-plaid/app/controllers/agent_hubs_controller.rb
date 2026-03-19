class AgentHubsController < ApplicationController
  layout "agent_hub"
  before_action :authenticate_user!
  before_action :require_owner

  def show
    @personas = [
      { id: "sap", name: "SAP" },
      { id: "conductor", name: "Conductor" },
      { id: "cwa", name: "CWA" },
      { id: "ai_financial_advisor", name: "AiFinancialAdvisor" },
      { id: "workflow_monitor", name: "Workflow Monitor" },
      { id: "debug", name: "Debug" }
    ]
    @active_persona_id = params[:persona_id] || session[:active_persona_id] || "sap"
    session[:active_persona_id] = @active_persona_id

    # Load conversations for current user and persona
    @conversations = SapRun.for_user_and_persona(current_user.id, @active_persona_id)
    @active_conversation = if params[:conversation_id].present?
      SapRun.find_by(id: params[:conversation_id], user_id: current_user.id)
    else
      @conversations.first
    end

    # Store active conversation in session
    session[:active_conversation_id] = @active_conversation&.id

    @selected_model = session[:global_model_override]

    # Linking Logic (PRD-AH-009C)
    @workflow_runs = AiWorkflowRun.for_user(current_user).active.order(updated_at: :desc)
    @active_run = params[:run_id].present? ? AiWorkflowRun.for_user(current_user).find(params[:run_id]) : nil
    @active_artifact = @active_run&.active_artifact || @active_conversation&.artifact || @workflow_runs.first&.active_artifact

    # Epic-0 PRD-0030: gate the advisor chat persona until there is at least one
    # successfully linked PlaidItem for this user.
    @advisor_chat_state = Rails.cache.fetch("user:#{current_user.id}:advisor_chat_state", expires_in: 5.minutes) do
      if current_user.plaid_items.successfully_linked.exists?
        :active
      else
        ever_successful = SyncLog.joins(:plaid_item)
          .where(plaid_items: { user_id: current_user.id })
          .where(status: "success")
          .exists?

        ever_successful ? :degraded : :needs_link
      end
    end

    Rails.logger.info({
      event: "agent_hub_persona_switch",
      user_id: current_user.id,
      persona_id: @active_persona_id,
      conversation_id: @active_conversation&.id,
      active_conversation_present: @active_conversation.present?,
      conversations_count: @conversations.count,
      model_override: session[:global_model_override],
      timestamp: Time.current
    }.to_json)

    if params[:persona_id].present? && params[:turbo_frame].present?
      # Optional: Broadcast a "..." message when switching
      ActionCable.server.broadcast("agent_hub_channel_#{@active_persona_id}-agent", { type: "typing", status: "start" })
    end

    render layout: false if params[:turbo_frame].present?
  end

  def update_model
    session[:global_model_override] = params[:model].presence

    # Reload the Agent Hub view
    redirect_to agent_hub_path(persona_id: session[:active_persona_id] || "sap", turbo_frame: "agent_hub_content")
  end

  def inspect_context
    # Fetch RAG context for the current persona/user
    persona_id = session[:active_persona_id] || "sap"
    rag_request_id = params[:rag_request_id]

    # Use SapAgent::RagProvider to build a prefix (simulating context fetch)
    # If rag_request_id is provided, we use it to trace the re-inspection
    context_prefix = SapAgent::RagProvider.build_prefix("default", current_user.id, persona_id, session[:active_conversation_id], request_id: rag_request_id)

    render json: {
      persona: persona_id,
      rag_request_id: rag_request_id || "live-snapshot",
      timestamp: Time.current,
      context_prefix: context_prefix
    }
  end

  def create_conversation
    persona_id = params[:persona_id] || session[:active_persona_id] || "sap"
    conversation = SapRun.create_conversation(
      user_id: current_user.id,
      persona_id: persona_id
    )

    session[:active_conversation_id] = conversation.id

    redirect_to agent_hub_path(persona_id: persona_id, conversation_id: conversation.id)
  end

  def switch_conversation
    conversation = SapRun.find_by(id: params[:conversation_id], user_id: current_user.id)

    if conversation
      session[:active_conversation_id] = conversation.id

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("chat-pane",
            partial: "agent_hubs/chat_pane",
            locals: { conversation: conversation }
          )
        end
        format.html { redirect_to agent_hub_path(conversation_id: conversation.id) }
      end
    else
      head :not_found
    end
  end

  def archive_conversation
    conversation = SapRun.find_by(id: params[:conversation_id], user_id: current_user.id)

    if conversation
      conversation.update!(status: :aborted)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.remove("conversation-#{conversation.id}")
        end
        format.html { redirect_to agent_hub_path }
      end
    else
      head :not_found
    end
  end

  def archive_run
    run = AiWorkflowRun.for_user(current_user).find(params[:run_id])
    run.archive!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("run-#{run.id}")
      end
      format.html { redirect_to agent_hub_path }
    end
  end

  def messages
    # In a real app, we would fetch from a database.
    # For this PRD, we'll return a stub to demonstrate polling capability.
    @agent_id = params[:agent_id]

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("messages-#{@agent_id}",
          "<div class='chat chat-start'><div class='chat-bubble italic text-xs text-gray-500'>[Polled at #{Time.current.strftime('%H:%M:%S')}] Connection lost, polling...</div></div>")
      end
    end
  end
end
