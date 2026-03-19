# frozen_string_literal: true

class CreateHoldingsSnapshotsJob < ApplicationJob
  queue_as :default

  # Use an explicit proc for exponential-style backoff to avoid framework
  # incompatibilities with `wait: :exponentially_longer`.
  retry_on StandardError, wait: ->(executions) { (executions**4) + 2 }, attempts: 3

  def perform(user_id:, account_id: nil, force: false)
    result = CreateHoldingsSnapshotService.new(
      user_id: user_id,
      account_id: account_id,
      force: force
    ).call

    return if result.success? || result.skipped? || result.permanent_failure?

    notify_admin_on_final_failure(user_id, result.error) if final_attempt?
    raise StandardError, result.error
  end

  private

  def final_attempt?
    executions.to_i >= 3
  end

  def notify_admin_on_final_failure(user_id, error)
    AdminNotificationJob.perform_later(
      subject: "Snapshot creation failed for user #{user_id}",
      message: error
    )
  end
end
