require "test_helper"

class SapRunTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @persona_id = "sap"
  end

  test "create_conversation creates unique correlation_id" do
    conversation1 = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    conversation2 = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)

    assert_not_equal conversation1.correlation_id, conversation2.correlation_id
    assert_match(/^agent-hub-#{@persona_id}-#{@user.id}-/, conversation1.correlation_id)
    assert_match(/^agent-hub-#{@persona_id}-#{@user.id}-/, conversation2.correlation_id)
  end

  test "create_conversation sets default title" do
    conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)

    assert_equal "New Conversation", conversation.title
    assert_equal "single_persona", conversation.conversation_type
    assert_equal "pending", conversation.status
  end

  test "create_conversation accepts custom title" do
    conversation = SapRun.create_conversation(
      user_id: @user.id,
      persona_id: @persona_id,
      title: "Custom Title"
    )

    assert_equal "Custom Title", conversation.title
  end

  test "for_user_and_persona returns correct conversations" do
    conversation1 = SapRun.create_conversation(user_id: @user.id, persona_id: "sap")
    conversation2 = SapRun.create_conversation(user_id: @user.id, persona_id: "conductor")
    conversation3 = SapRun.create_conversation(user_id: @user.id, persona_id: "sap")

    sap_conversations = SapRun.for_user_and_persona(@user.id, "sap")

    assert_includes sap_conversations, conversation1
    assert_includes sap_conversations, conversation3
    assert_not_includes sap_conversations, conversation2
  end

  test "for_user_and_persona excludes failed and aborted conversations" do
    active_conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    failed_conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    failed_conversation.update!(status: :failed)
    aborted_conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    aborted_conversation.update!(status: :aborted)

    conversations = SapRun.for_user_and_persona(@user.id, @persona_id)

    assert_includes conversations, active_conversation
    assert_not_includes conversations, failed_conversation
    assert_not_includes conversations, aborted_conversation
  end

  test "for_user_and_persona orders by updated_at desc" do
    conversation1 = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    sleep 0.01
    conversation2 = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    sleep 0.01
    conversation1.touch

    conversations = SapRun.for_user_and_persona(@user.id, @persona_id)

    assert_equal conversation1.id, conversations.first.id
    assert_equal conversation2.id, conversations.second.id
  end

  test "generate_title_from_first_message updates title from first user message" do
    conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    conversation.sap_messages.create!(role: :user, content: "This is a test message that should become the title")

    conversation.generate_title_from_first_message

    assert_equal "This is a test message that should become the t...", conversation.title
  end

  test "generate_title_from_first_message does not update if title is not 'New Conversation'" do
    conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id, title: "Custom Title")
    conversation.sap_messages.create!(role: :user, content: "This should not become the title")

    conversation.generate_title_from_first_message

    assert_equal "Custom Title", conversation.title
  end

  test "conversation_type enum works correctly" do
    conversation = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)

    assert conversation.single_persona_conversation_type?

    conversation.update!(conversation_type: :multi_persona)
    assert conversation.multi_persona_conversation_type?

    conversation.update!(conversation_type: :workflow)
    assert conversation.workflow_conversation_type?
  end

  test "active scope excludes failed and aborted" do
    active = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    failed = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    failed.update!(status: :failed)
    aborted = SapRun.create_conversation(user_id: @user.id, persona_id: @persona_id)
    aborted.update!(status: :aborted)

    active_conversations = SapRun.active

    assert_includes active_conversations, active
    assert_not_includes active_conversations, failed
    assert_not_includes active_conversations, aborted
  end
end
