require "test_helper"

class AgentHub::UploadsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one) # Assuming this fixture exists
    @run = ai_workflow_runs(:one) # Assuming this fixture exists
  end

  test "should upload a file and attach it to the run" do
    sign_in @user

    file = fixture_file_upload("test/fixtures/files/test_log.txt", "text/plain")

    assert_difference "ActiveStorage::Attachment.count", 1 do
      post agent_hub_uploads_url, params: { run_id: @run.id, files: [ file ] }
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "test_log.txt", json_response["attachments"].first["filename"]
  end

  test "should require authentication" do
    file = fixture_file_upload("test/fixtures/files/test_log.txt", "text/plain")
    post agent_hub_uploads_url, params: { run_id: @run.id, files: [ file ] }
    assert_redirected_to new_user_session_path
  end
end
