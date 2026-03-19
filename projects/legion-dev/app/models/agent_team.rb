# frozen_string_literal: true

class AgentTeam < ApplicationRecord
  belongs_to :project, optional: true
  has_many :team_memberships, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id }
end
