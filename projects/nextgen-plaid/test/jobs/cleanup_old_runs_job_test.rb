require "test_helper"

class CleanupOldRunsJobTest < ActiveJob::TestCase
  test "should archive runs older than threshold" do
    owner = User.create!(email: "owner_cleanup@example.com", password: "password", roles: [ "admin" ])

    old_run = AiWorkflowRun.create!(user: owner, status: "draft", metadata: { "foo" => "bar" })
    old_run.update_columns(updated_at: 31.days.ago)

    recent_run = AiWorkflowRun.create!(user: owner, status: "draft", metadata: { "foo" => "bar" })
    recent_run.update_columns(updated_at: 1.day.ago)

    assert_difference "AiWorkflowRun.active.count", -1 do
      CleanupOldRunsJob.perform_now
    end

    assert_not_nil old_run.reload.archived_at
    assert_nil recent_run.reload.archived_at
  end
end
