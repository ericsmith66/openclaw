require "test_helper"

class ChatPaneComponentTest < ViewComponent::TestCase
  test "renders markdown content in messages" do
    require "ostruct"
    msg = OpenStruct.new(user_role?: false, content: "Hello **world**")

    sap_messages = Object.new
    sap_messages.define_singleton_method(:order) { |_| [ msg ] }

    conv = OpenStruct.new(sap_messages: sap_messages)

    render_inline(ChatPaneComponent.new(agent_id: "test-agent", conversation: conv))

    assert_selector ".chat-bubble strong", text: "world"
  end
end
