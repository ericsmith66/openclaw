class CleanupOldRunsJob < ApplicationJob
  queue_as :default

  def perform
    threshold_days = (ENV["RUN_CLEANUP_THRESHOLD_DAYS"] || 30).to_i
    cutoff = threshold_days.days.ago

    # We'll archive them instead of hard deleting to be safe, per PRD 007C's spirit
    runs_to_cleanup = AiWorkflowRun.active.where("updated_at < ?", cutoff)

    count = runs_to_cleanup.count
    runs_to_cleanup.find_each(&:archive!)

    Rails.logger.info "CleanupOldRunsJob: Archived #{count} runs older than #{threshold_days} days."
  end
end
