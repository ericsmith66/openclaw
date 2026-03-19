require "test_helper"

class SignOutTest < ActionDispatch::IntegrationTest
  test "user can sign out and loses access to authenticated pages" do
    user = users(:one)

    sign_in user
    get dashboard_path
    assert_response :success

    delete destroy_user_session_path
    assert_response :redirect

    # Devise typically redirects to `root_path` after logout.
    assert_redirected_to root_path

    # In this app, `root_path` then redirects unauthenticated users to sign-in
    # in non-development environments.
    follow_redirect!
    follow_redirect! if response.redirect?
    assert_equal new_user_session_path, request.path

    get dashboard_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end
end
