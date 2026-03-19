require "test_helper"

class Admin::OwnershipLookupsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @parent_user = User.create!(email: "parent@example.com", password: "Password!123", roles: "parent")
    @kid_user = User.create!(email: "kid@example.com", password: "Password!123", roles: "kid")
    @lookup = OwnershipLookup.create!(name: "Family Trust", ownership_type: "Trust", details: "Example")
  end

  test "parent can access index" do
    login_as @parent_user, scope: :user
    get admin_ownership_lookups_path
    assert_response :success
  end

  test "kid cannot access index" do
    login_as @kid_user, scope: :user
    get admin_ownership_lookups_path
    assert_redirected_to authenticated_root_path
  end

  test "parent can view show" do
    login_as @parent_user, scope: :user
    get admin_ownership_lookup_path(@lookup)
    assert_response :success
  end

  test "kid cannot view show" do
    login_as @kid_user, scope: :user
    get admin_ownership_lookup_path(@lookup)
    assert_redirected_to authenticated_root_path
  end
end
