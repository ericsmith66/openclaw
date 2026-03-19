class SensorValueDefinition < ApplicationRecord
  belongs_to :room
  belongs_to :accessory
  belongs_to :sensor

  validates :value, presence: true
  validates :sensor_id, uniqueness: { scope: :value }

  scope :for_sensor, ->(sensor) { where(sensor: sensor) }

  def self.discover!(sensor, value, timestamp)
    definition = find_or_initialize_by(sensor: sensor, value: value.to_s)
    definition.room = sensor.room
    definition.accessory = sensor.accessory
    definition.last_seen_at = timestamp
    definition.occurrence_count += 1

    # Auto-assign labels and units for sensors if blank
    if definition.label.blank?
      definition.label = sensor.format_value(value)
    end

    if definition.units.blank?
      definition.units = sensor.value_unit
    end

    definition.save!
    definition
  end
end
