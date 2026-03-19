# app/jobs/plaid_api_responses_retention_job.rb
class PlaidApiResponsesRetentionJob < ApplicationJob
  queue_as :default

  RETENTION_DAYS = 30

  def perform
    cutoff = RETENTION_DAYS.days.ago
    PlaidApiResponse.where("called_at < ?", cutoff).delete_all
  end
end
