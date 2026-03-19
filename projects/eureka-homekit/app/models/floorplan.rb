class Floorplan < ApplicationRecord
  belongs_to :home
  has_one_attached :svg_file
  has_one_attached :mapping_file

  validates :level, presence: true
  validates :name, presence: true
end
