require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "root redirects to sign-in when not in development" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      get root_path
      assert_response :redirect
      assert_redirected_to new_user_session_path
    end
  end

  test "welcome page does not include hard-coded shortcut credentials" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
      get root_path
      assert_response :success

      refute_includes response.body, "LOGIN AS ERIC"
      refute_includes response.body, "E12345!"
      refute_includes response.body, "ericsmith66@me.com"
    end
  end
end
