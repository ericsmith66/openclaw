# frozen_string_literal: true

class AdminNotificationJob < ApplicationJob
  queue_as :default

  def perform(subject:, message:)
    Rails.logger.error({ job: self.class.name, subject: subject, message: message }.to_json)
  end
end
