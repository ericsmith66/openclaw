# frozen_string_literal: true

class CreateTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :team_memberships do |t|
      t.references :agent_team, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.jsonb :config, null: false, default: {}
      t.timestamps
    end

    add_index :team_memberships, [ :agent_team_id, :position ]
  end
end
