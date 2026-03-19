require "test_helper"

class AgentHubMobileLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @owner_email = ENV["OWNER_EMAIL"].presence || "ericsmith66@me.com"
    @owner = User.find_or_initialize_by(email: @owner_email)
    @owner.password = "password123"
    @owner.roles = "admin"
    @owner.family_id = "1"
    @owner.save!
    sign_in @owner, scope: :user
  end

  test "mobile layout has drawer toggle and sidebar" do
    # Simulate mobile viewport by checking for classes that should be present/hidden
    get agent_hub_url
    assert_response :success

    # Drawer toggle should be visible on small screens
    assert_select "label[for='agent-hub-drawer']", minimum: 1

    # Desktop menu should be present but hidden on small screens
    assert_select ".flex-none.hidden.lg\\:block", count: 1

    # Drawer side should contain navigation
    assert_select ".drawer-side .menu", count: 1
    assert_select ".drawer-side a", text: "Mission Control"
  end
end
