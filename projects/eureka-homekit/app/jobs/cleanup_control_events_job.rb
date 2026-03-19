# frozen_string_literal: true

class CleanupControlEventsJob < ApplicationJob
  queue_as :low

  RETENTION_PERIOD = 30.days

  def perform
    count = ControlEvent.where("created_at < ?", RETENTION_PERIOD.ago).delete_all
    Rails.logger.info "[CleanupControlEventsJob] Deleted #{count} control events older than #{RETENTION_PERIOD.inspect}"
    count
  end
end
