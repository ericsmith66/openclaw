class HomekitEvent < ApplicationRecord
  belongs_to :accessory, optional: true
  belongs_to :sensor, optional: true

  has_one :room, through: :accessory
  has_one :home, through: :room

  validates :event_type, presence: true
  validates :timestamp, presence: true

  def severity
    "info" # Placeholder for now
  end

  def details
    { "message" => event_type }
  end

  def self.recent_grouped(scope: all, limit: 15)
    # Simple grouping by accessory, characteristic, and value within 30 seconds
    # This is a basic implementation, can be optimized with SQL window functions if needed
    events = scope.includes(:accessory, :sensor, accessory: :room).order(timestamp: :desc).limit(limit * 5)

    grouped = []
    events.each do |event|
      last_event = grouped.last&.first
      if last_event &&
         last_event.accessory_id == event.accessory_id &&
         last_event.characteristic == event.characteristic &&
         last_event.value == event.value &&
         (last_event.timestamp - event.timestamp).abs < 30

        grouped.last[1] += 1
      else
        grouped << [ event, 1 ]
      end
      break if grouped.size >= limit
    end
    grouped
  end
end
