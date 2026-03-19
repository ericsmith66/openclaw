class PersonaChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_persona

  PAGE_SIZE = 50

  def index
    @page = 1
    @conversations = fetch_conversations(page: @page)
    @active_conversation = find_active_conversation(@conversations)
    @available_models = AgentHub::ModelDiscoveryService.call
    @next_page = next_page_for(page: @page)

    render :index
  end

  def conversations
    page = params.fetch(:page, 1).to_i
    page = 1 if page < 1

    conversations = fetch_conversations(page: page)
    next_page = next_page_for(page: page)

    respond_to do |format|
      format.turbo_stream do
        rendered_items = render_to_string(
          partial: "persona_chats/sidebar_items",
          formats: [ :html ],
          locals: {
            persona_id: @persona_id,
            conversations: conversations,
            active_conversation_id: params[:active_conversation_id]
          }
        )

        render turbo_stream: [
          turbo_stream.append("conversation-items", rendered_items),
          turbo_stream.replace(
            "load-more",
            render_to_string(
              partial: "persona_chats/load_more",
              formats: [ :html ],
              locals: {
                persona_id: @persona_id,
                next_page: next_page,
                active_conversation_id: params[:active_conversation_id]
              }
            )
          )
        ]
      end

      format.html do
        render partial: "persona_chats/sidebar_list",
               locals: {
                 persona_id: @persona_id,
                 conversations: conversations,
                 next_page: next_page,
                 active_conversation_id: params[:active_conversation_id]
               },
               layout: false
      end
    end
  end

  def show
    conversation = PersonaConversation
      .for_persona(@persona_id)
      .for_user(current_user)
      .find(params[:id])

    # This endpoint is typically loaded into the `chat-pane-frame` Turbo Frame.
    # Turbo requires the response to include a matching `<turbo-frame id="chat-pane-frame">`.
    render PersonaChats::ChatPaneComponent.new(persona_id: @persona_id, conversation: conversation), layout: false
  end

  def render_message
    message = PersonaMessage
      .joins(:persona_conversation)
      .merge(PersonaConversation.for_persona(@persona_id).for_user(current_user))
      .find(params[:id])

    raise ActiveRecord::RecordNotFound unless message.role == "assistant"

    rendered = PersonaChats::AssistantMessageRenderer.call(
      content: message.content,
      sources: message.metadata&.dig("sources") || [],
      model: message.metadata&.dig("model") || "",
      provider_model: message.metadata&.dig("provider_model") || ""
    )

    render json: {
      message_id: message.id,
      content_html: rendered
    }
  end

  def create_conversation
    conversation = PersonaConversation.create_conversation(user_id: current_user.id, persona_id: @persona_id)

    respond_to do |format|
      format.turbo_stream do
        @conversations = fetch_conversations(page: 1)
        @available_models = AgentHub::ModelDiscoveryService.call

        render turbo_stream: [
          turbo_stream.replace(
            "conversation-sidebar-frame",
            PersonaChats::SidebarComponent.new(
              persona_id: @persona_id,
              conversations: @conversations,
              active_conversation_id: conversation.id,
              next_page: next_page_for(page: 1)
            )
          ),
          turbo_stream.replace(
            "chat-pane-frame",
            PersonaChats::ChatPaneComponent.new(persona_id: @persona_id, conversation: conversation)
          ),
          turbo_stream.replace(
            "model-selector-frame",
            PersonaChats::ModelSelectorComponent.new(
              persona_id: @persona_id,
              conversation: conversation,
              available_models: @available_models
            )
          )
        ]
      end
      format.html { redirect_to persona_chats_path(persona_id: @persona_id, conversation_id: conversation.id) }
    end
  rescue StandardError => e
    Rails.logger.error("[PersonaChat] create_conversation_failed persona=#{@persona_id} user=#{current_user.id} error=#{e.class}:#{e.message}")
    redirect_to persona_chats_path(persona_id: @persona_id), alert: "Failed to create conversation—try again"
  end

  def update_model
    conversation = PersonaConversation
      .for_persona(@persona_id)
      .for_user(current_user)
      .find(params[:id])

    new_model = params[:llm_model].to_s
    old_model = conversation.llm_model
    conversation.update!(llm_model: new_model)

    Rails.logger.info("[PersonaChat] model_switch user=#{current_user.id} conversation=#{conversation.id} from=#{old_model} to=#{new_model}")

    respond_to do |format|
      format.turbo_stream do
        @available_models = AgentHub::ModelDiscoveryService.call
        render turbo_stream: turbo_stream.replace(
          "model-selector-frame",
          PersonaChats::ModelSelectorComponent.new(
            persona_id: @persona_id,
            conversation: conversation,
            available_models: @available_models,
            toast: "Model changed to #{new_model}. This will apply to your next message."
          )
        )
      end
      format.html { redirect_to persona_chats_path(persona_id: @persona_id, conversation_id: conversation.id) }
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to persona_chats_path(persona_id: @persona_id, conversation_id: params[:id]), alert: "Failed to update model—try again"
  end

  private

  def set_persona
    @persona_id = params[:persona_id].to_s
    raise ActiveRecord::RecordNotFound if Personas.find(@persona_id).blank?
  end

  def fetch_conversations(page:)
    offset = (page - 1) * PAGE_SIZE
    PersonaConversation
      .for_persona(@persona_id)
      .for_user(current_user)
      .recent_first
      .offset(offset)
      .limit(PAGE_SIZE)
      .to_a
  end

  def next_page_for(page:)
    offset = page * PAGE_SIZE
    has_more = PersonaConversation
      .for_persona(@persona_id)
      .for_user(current_user)
      .offset(offset)
      .limit(1)
      .exists?

    has_more ? (page + 1) : nil
  end

  def find_active_conversation(conversations)
    if params[:conversation_id].present?
      PersonaConversation
        .for_persona(@persona_id)
        .for_user(current_user)
        .find_by(id: params[:conversation_id])
    else
      conversations.first
    end
  end
end
