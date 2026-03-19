require "test_helper"

class ConversationSidebarComponentTest < ViewComponent::TestCase
  test "renders conversation sidebar and badges" do
    conversations = [
      OpenStruct.new(id: 1, title: "Investment Strategy", pending_count: 3, status: "pending", updated_at: Time.current),
      OpenStruct.new(id: 2, title: "Tax Planning 2025", pending_count: 0, status: "complete", updated_at: Time.current)
    ]
    render_inline(ConversationSidebarComponent.new(conversations: conversations))

    assert_selector "h2", text: "Conversations"
    assert_selector "span", text: "Investment Strategy"
    assert_selector "span.badge", text: "!"
  end

  test "has sidebar controller data attributes" do
    render_inline(ConversationSidebarComponent.new(conversations: []))
    assert_selector "[data-controller~='sidebar']"
    assert_selector "[data-controller~='search']"
    assert_selector "[data-sidebar-target='sidebar']"
    assert_selector "[data-action='click->sidebar#toggle']"
    assert_selector "input[data-search-target='input']"
  end
end
