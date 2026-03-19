class AddRoleToTeamMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :team_memberships, :role, :string
  end
end
