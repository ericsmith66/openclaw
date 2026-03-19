class ControlEvent < ApplicationRecord
  belongs_to :accessory, optional: true
  belongs_to :scene, optional: true

  alias_attribute :characteristic, :characteristic_name

  validates :action_type, presence: true, inclusion: { in: %w[set_characteristic execute_scene] }
  validates :success, inclusion: { in: [ true, false ] }

  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :for_accessory, ->(accessory_id) { where(accessory_id: accessory_id) }
  scope :for_scene, ->(scene_id) { where(scene_id: scene_id) }
  scope :from_source, ->(source) { where(source: source) }
  scope :recent_within, ->(time_range = 24.hours.ago) { where("created_at >= ?", time_range) }

  def self.success_rate(time_range = 24.hours.ago)
    records = where("created_at >= ?", time_range).group(:success).count
    total = records.values.sum
    return 0.0 if total.zero?
    (records.fetch(true, 0).to_f / total * 100).round(2)
  end

  def self.average_latency(time_range = 24.hours.ago)
    where("created_at >= ?", time_range).average(:latency_ms).to_f.round(2)
  end
end
