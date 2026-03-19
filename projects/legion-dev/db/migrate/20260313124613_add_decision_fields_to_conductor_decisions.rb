class AddDecisionFieldsToConductorDecisions < ActiveRecord::Migration[8.1]
  def change
    add_column :conductor_decisions, :tool_name, :string
    add_column :conductor_decisions, :tool_args, :jsonb
    add_column :conductor_decisions, :from_phase, :string
    add_column :conductor_decisions, :to_phase, :string
    add_column :conductor_decisions, :reasoning, :text
    add_column :conductor_decisions, :input_summary, :text
  end
end
