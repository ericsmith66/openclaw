# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :agent_teams, dependent: :destroy
  has_many :workflow_runs, dependent: :destroy
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  validates :path, presence: true, uniqueness: true

  def prd_content
    ""
  end

  def acceptance_criteria
    ""
  end
end
