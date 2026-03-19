require "test_helper"

class Admin::HealthControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = User.create!(email: "admin@example.com", password: "Password!123", roles: "admin")
    @non_admin_user = User.create!(email: "parent@example.com", password: "Password!123", roles: "parent")
  end

  test "admin can access health json" do
    login_as @admin_user, scope: :user
    get admin_health_path(format: :json)
    assert_response :success

    payload = JSON.parse(response.body)
    assert payload.key?("status")
    assert payload.key?("checked_at")
    assert payload.key?("components")
    assert payload["components"].key?("solid_queue")

    sq = payload.dig("components", "solid_queue")
    assert sq.key?("queue_depth")
    assert sq.dig("queue_depth", "by_queue")
    assert sq.dig("dashboard", "last_finished_by_class")
    assert sq.dig("dashboard", "recurring_tasks")
  end

  test "non-admin cannot access health json" do
    login_as @non_admin_user, scope: :user
    get admin_health_path(format: :json)
    assert_response :forbidden
  end

  test "stale alert triggers when last finished job is older than threshold" do
    login_as @admin_user, scope: :user

    process = SolidQueue::Process.create!(
      name: "test-process",
      kind: "worker",
      pid: 12_345,
      last_heartbeat_at: Time.current,
      created_at: Time.current
    )

    old_job = SolidQueue::Job.create!(
      class_name: "TestJob",
      queue_name: "default",
      arguments: "[]",
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago,
      finished_at: 2.hours.ago
    )
    SolidQueue::ClaimedExecution.create!(job_id: old_job.id, process_id: process.id, created_at: 2.hours.ago)

    get admin_health_path(format: :json)
    assert_response :success

    payload = JSON.parse(response.body)
    sq = payload.dig("components", "solid_queue")
    assert_equal true, sq.dig("alerts", "stale_no_jobs_processed")
  end
end
