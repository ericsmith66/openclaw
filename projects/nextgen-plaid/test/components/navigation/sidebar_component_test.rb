# frozen_string_literal: true

require "test_helper"

class Navigation::SidebarComponentTest < ViewComponent::TestCase
  def test_regular_user_does_not_render_admin_section
    user = User.new(email: "regular@example.com")

    render_inline(Navigation::SidebarComponent.new(current_user: user, drawer_id: "test-drawer"))

    refute_text "Admin"
    refute_link "Health"
    refute_link "Mission Control"
    refute_link "Agent Hub"
    refute_link "Simulations"
  end

  def test_owner_user_renders_admin_section
    owner_email = ENV.fetch("OWNER_EMAIL", "ericsmith66@me.com")
    user = User.new(email: owner_email)

    render_inline(Navigation::SidebarComponent.new(current_user: user, drawer_id: "test-drawer"))

    assert_text "Admin"
    assert_link "Health", href: "/admin/health"
    assert_link "Mission Control"
    assert_link "Agent Hub"
    assert_link "Simulations"
  end
end
