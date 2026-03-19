require "test_helper"

class AgentHubsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner_email = ENV["OWNER_EMAIL"].presence || "ericsmith66@me.com"
    @owner = User.find_or_initialize_by(email: @owner_email)
    @owner.password = "password123"
    @owner.roles = "admin"
    @owner.family_id = "1"
    @owner.save!

    @non_owner = User.find_or_initialize_by(email: "other@example.com")
    @non_owner.password = "password123"
    @non_owner.roles = "parent"
    @non_owner.family_id = "1"
    @non_owner.save!
  end

  test "should redirect to login if not authenticated" do
    get agent_hub_url
    assert_redirected_to new_user_session_path
  end

  test "should allow access to owner" do
    sign_in @owner, scope: :user
    get agent_hub_url
    assert_response :success
    assert_select ".tabs", count: 1
    assert_select "a", text: "SAP"
    assert_select "a", text: "Conductor"
    assert_select "a", text: "CWA"
    assert_select "a", text: "AiFinancialAdvisor"
    assert_select "a", text: "Workflow Monitor"
    assert_select "a", text: "Debug"
  end

  test "should deny access to non-owner" do
    sign_in @non_owner, scope: :user
    get agent_hub_url
    assert_redirected_to authenticated_root_path
  end

  test "should log access to agent_hub" do
    sign_in @owner, scope: :user
    get agent_hub_url
    assert_response :success
  end

  test "should switch persona and update session" do
    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "conductor")
    assert_response :success
    assert_equal "conductor", session[:active_persona_id]
    assert_select "a.tab-active.bg-emerald-600", text: "Conductor"
  end

  test "should update global model override" do
    sign_in @owner, scope: :user
    model_name = "llama3.1:8b"
    post update_model_agent_hubs_url(model: model_name)
    assert_redirected_to agent_hub_path(persona_id: "sap", turbo_frame: "agent_hub_content")
    follow_redirect!
    assert_equal model_name, controller.session[:global_model_override]
    assert_select "button", text: /#{model_name}/
  end

  test "should inspect context" do
    sign_in @owner, scope: :user
    get inspect_context_agent_hubs_url
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "sap", json["persona"]
    assert_includes json["context_prefix"], "[CONTEXT START]"
  end
  test "should list actual SapRun records" do
    SapRun.create_conversation(user_id: @owner.id, persona_id: "sap", title: "Test Conv 1")
    SapRun.create_conversation(user_id: @owner.id, persona_id: "sap", title: "Test Conv 2")

    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "sap")
    assert_response :success
    assert_select "span", text: "Test Conv 1"
    assert_select "span", text: "Test Conv 2"
  end

  test "should auto-title new conversations" do
    sign_in @owner, scope: :user
    conversation = SapRun.create_conversation(user_id: @owner.id, persona_id: "sap")
    assert_equal "New Conversation", conversation.title

    get agent_hub_url(persona_id: "sap")
    assert_select "span", text: "New Conversation"
  end

  test "should load active conversation when conversation_id is provided" do
    conversation = SapRun.create_conversation(user_id: @owner.id, persona_id: "sap", title: "Active Conv")

    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "sap", conversation_id: conversation.id)
    assert_response :success
    assert_select "div.bg-blue-500", text: /Active Conv/
  end
  test "should archive a run" do
    run = AiWorkflowRun.create!(user: @owner, status: "draft", metadata: { "foo" => "bar" })

    sign_in @owner, scope: :user
    delete archive_run_agent_hubs_url(run_id: run.id), as: :turbo_stream
    assert_response :success

    run.reload
    assert_not_nil run.archived_at
    assert_match /turbo-stream action="remove" target="run-#{run.id}"/, response.body
  end

  test "workflow monitor should be read-only" do
    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "workflow_monitor")
    assert_response :success
    assert_select "h1", text: /Workflow Monitor \(Read-only\)/
    assert_select "input[data-input-bar-target='input']", count: 0
  end

  # Conversation Management Tests (PRD-AH-008E)
  test "should create new conversation" do
    sign_in @owner, scope: :user

    assert_difference "SapRun.count", 1 do
      post create_conversation_agent_hubs_url, params: { persona_id: "sap" }
    end

    conversation = SapRun.last
    assert_equal @owner.id, conversation.user_id
    assert_match(/^agent-hub-sap-#{@owner.id}-/, conversation.correlation_id)
    assert_equal "New Conversation", conversation.title
    assert_equal "pending", conversation.status
  end

  test "should list conversations for user and persona" do
    conversation1 = SapRun.create_conversation(user_id: @owner.id, persona_id: "sap", title: "Conv 1")
    conversation2 = SapRun.create_conversation(user_id: @owner.id, persona_id: "sap", title: "Conv 2")
    conversation3 = SapRun.create_conversation(user_id: @owner.id, persona_id: "conductor", title: "Conv 3")

    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "sap")
    assert_response :success

    assert_select "span.font-medium", text: "Conv 1"
    assert_select "span.font-medium", text: "Conv 2"
    assert_select "span.font-medium", text: "Conv 3", count: 0
  end

  test "should switch to selected conversation" do
    conversation = SapRun.create_conversation(user_id: @owner.id, persona_id: "sap", title: "Test Conv")
    conversation.sap_messages.create!(role: :user, content: "Hello")
    conversation.sap_messages.create!(role: :assistant, content: "Hi there")

    sign_in @owner, scope: :user
    get agent_hub_url(conversation_id: conversation.id, persona_id: "sap")
    assert_response :success

    assert_equal conversation.id, session[:active_conversation_id]
    assert_select "div.chat-bubble", text: /Hello/
    assert_select "div.chat-bubble", text: /Hi there/
  end

  test "should archive conversation" do
    conversation = SapRun.create_conversation(user_id: @owner.id, persona_id: "sap")

    sign_in @owner, scope: :user
    delete archive_conversation_agent_hubs_url(conversation_id: conversation.id), as: :turbo_stream
    assert_response :success

    conversation.reload
    assert_equal "aborted", conversation.status
    assert_match /turbo-stream action="remove" target="conversation-#{conversation.id}"/, response.body
  end

  test "should not allow access to other user's conversations" do
    other_conversation = SapRun.create_conversation(user_id: @non_owner.id, persona_id: "sap")

    sign_in @owner, scope: :user
    get agent_hub_url(conversation_id: other_conversation.id, persona_id: "sap")
    assert_response :success

    # Should not load the other user's conversation
    assert_not_equal other_conversation.id, session[:active_conversation_id]
  end

  test "should display new conversation button" do
    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "sap")
    assert_response :success

    assert_select "button", text: /New Conversation/
  end

  test "should show empty state when no conversations exist" do
    sign_in @owner, scope: :user
    get agent_hub_url(persona_id: "sap")
    assert_response :success

    assert_select "li", text: /No conversations yet/
  end
end
