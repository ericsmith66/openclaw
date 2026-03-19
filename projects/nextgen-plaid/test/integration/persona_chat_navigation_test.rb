require "test_helper"

class PersonaChatNavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "index renders for valid persona" do
    user = users(:one)
    sign_in user

    get persona_chats_path(persona_id: "financial-advisor")
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes @response.body, "Chat: financial-advisor"
  end

  test "chats root redirects to default persona" do
    user = users(:one)
    sign_in user

    get "/chats"
    assert_response :redirect
    assert_equal "/chats/financial-advisor", URI.parse(response.location).path
  end
end
