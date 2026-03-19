class AddConversationFieldsToSapRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :sap_runs, :title, :string
    add_column :sap_runs, :conversation_type, :string, default: 'single_persona'
    add_index :sap_runs, [ :user_id, :status, :updated_at ]
  end
end
