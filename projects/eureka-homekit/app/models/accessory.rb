class Accessory < ApplicationRecord
  belongs_to :room
  has_many :scene_accessories, dependent: :destroy
  has_many :scenes, through: :scene_accessories
  has_many :sensors, dependent: :destroy
  has_many :homekit_events, dependent: :destroy

  validates :name, presence: true
  validates :uuid, presence: true, uniqueness: true

  def update_liveness!(timestamp)
    update_columns(last_seen_at: timestamp)
  end
end
