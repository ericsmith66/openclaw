require "test_helper"

class PersonaChatSidebarPaginationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "sidebar pagination turbo_stream appends more conversations" do
    user = users(:one)
    sign_in user

    # Create 55 conversations so page 2 exists (PAGE_SIZE = 50)
    55.times do |i|
      PersonaConversation.create!(
        user: user,
        persona_id: "financial-advisor",
        llm_model: "llama3.1:70b",
        title: "Chat #{i}"
      )
    end

    get persona_chat_conversations_path(persona_id: "financial-advisor", page: 2),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.media_type, "turbo-stream"
    assert_includes response.body, "<turbo-stream action=\"append\" target=\"conversation-items\""
    assert_includes response.body, "conversation-"
  end
end
