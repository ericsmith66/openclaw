require "test_helper"

class InputBarComponentTest < ViewComponent::TestCase
  test "renders input bar with data attributes" do
    render_inline(InputBarComponent.new(agent_id: "test-agent"))

    assert_selector "[data-controller='input-bar']"
    assert_selector "input[placeholder='Message agent...']"
    assert_selector "button", text: "Send"
    assert_selector "[data-input-bar-target='autocomplete'].hidden"
  end
end
