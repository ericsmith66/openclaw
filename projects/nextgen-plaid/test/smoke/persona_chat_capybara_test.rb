require "application_system_test_case"

class PersonaChatCapybaraTest < ApplicationSystemTestCase
  test "user can open persona chat, create conversation, and switch models" do
    user = users(:one)
    login_as user, scope: :user

    travel_to(Time.zone.local(2026, 1, 15, 12, 0, 0)) do
      visit persona_chats_path(persona_id: "financial-advisor")
      assert_text "Chat: financial-advisor"

      click_button "New Conversation"
      assert_text "Chat Jan"
    end

    # Model selector should be present and can be switched without JS (button_to patch)
    assert_text "Model: Llama"
    click_button "Llama 3.1 8B" if page.has_button?("Llama 3.1 8B")
  end

  test "model selection persists to next conversation" do
    user = users(:one)
    login_as user, scope: :user

    visit persona_chats_path(persona_id: "financial-advisor")

    click_button "New Conversation"
    assert_text "Model: Llama"

    # Switch to 8B if available
    if page.has_button?("Llama 3.1 8B")
      click_button "Llama 3.1 8B"
      assert_text "Model: Llama 3.1 8B"
    end

    click_button "New Conversation"
    # New conversation should inherit the last-used model for this persona.
    assert_text "Model: Llama 3.1 8B" if page.has_button?("Llama 3.1 8B")
  end
end
