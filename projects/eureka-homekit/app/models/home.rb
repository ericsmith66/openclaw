class Home < ApplicationRecord
  has_many :rooms, dependent: :destroy
  has_many :floorplans, dependent: :destroy
  has_many :scenes, dependent: :destroy
  has_many :accessories, through: :rooms
  has_many :sensors, through: :accessories
  has_many :homekit_events, through: :accessories

  validates :name, presence: true
  validates :uuid, presence: true, uniqueness: true
end
