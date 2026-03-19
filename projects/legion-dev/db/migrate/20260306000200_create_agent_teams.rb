# frozen_string_literal: true

class CreateAgentTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_teams do |t|
      t.references :project, foreign_key: true, null: true  # optional — reusable teams
      t.string :name, null: false
      t.text :description
      t.jsonb :team_rules, null: false, default: {}
      t.timestamps
    end

    add_index :agent_teams, [ :project_id, :name ], unique: true
  end
end
