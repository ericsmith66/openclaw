class SceneAccessory < ApplicationRecord
  belongs_to :scene
  belongs_to :accessory

  validates :scene_id, presence: true
  validates :accessory_id, presence: true
end
