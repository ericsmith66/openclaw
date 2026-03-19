class Scene < ApplicationRecord
  belongs_to :home
  has_many :scene_accessories, dependent: :destroy
  has_many :accessories, through: :scene_accessories

  validates :name, presence: true
  validates :uuid, presence: true, uniqueness: true
end
