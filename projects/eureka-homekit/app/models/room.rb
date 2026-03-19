class Room < ApplicationRecord
  belongs_to :home
  has_many :accessories, dependent: :destroy
  has_many :sensors, through: :accessories
  has_many :homekit_events, through: :accessories

  validates :name, presence: true
  validates :uuid, presence: true, uniqueness: true

  def update_liveness!(timestamp, is_motion: false)
    updates = { last_event_at: timestamp }
    updates[:last_motion_at] = timestamp if is_motion
    update_columns(updates)
  end
end
