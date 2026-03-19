require "test_helper"

class CreateHoldingsSnapshotsJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "raises to trigger retry on transient failure" do
    result = CreateHoldingsSnapshotService::Result.new(status: :failure, error: "boom", permanent: false)
    service_instance = OpenStruct.new(call: result)

    CreateHoldingsSnapshotService.stub(:new, service_instance) do
      assert_enqueued_jobs 1, only: CreateHoldingsSnapshotsJob do
        CreateHoldingsSnapshotsJob.perform_now(user_id: 123)
      end
    end
  end

  test "final_attempt? is true when executions >= 3" do
    job = CreateHoldingsSnapshotsJob.new
    job.instance_variable_set(:@executions, 3)
    assert_equal 3, job.executions

    assert job.send(:final_attempt?)
  end

  test "notify_admin_on_final_failure enqueues AdminNotificationJob" do
    job = CreateHoldingsSnapshotsJob.new

    assert_enqueued_with(job: AdminNotificationJob) do
      job.send(:notify_admin_on_final_failure, 123, "boom")
    end
  end

  test "does not retry permanent failures" do
    result = CreateHoldingsSnapshotService::Result.new(status: :failure, error: "not found", permanent: true)
    service_instance = OpenStruct.new(call: result)

    CreateHoldingsSnapshotService.stub(:new, service_instance) do
      assert_no_enqueued_jobs(only: AdminNotificationJob) do
        CreateHoldingsSnapshotsJob.perform_now(user_id: 123)
      end
    end
  end
end
