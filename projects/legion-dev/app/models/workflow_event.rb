# frozen_string_literal: true

class WorkflowEvent < ApplicationRecord
  belongs_to :workflow_run

  validates :event_type, presence: true
  validates :recorded_at, presence: true

  scope :by_type, ->(type) { where(event_type: type) }
  scope :chronological, -> { order(recorded_at: :asc) }
end
