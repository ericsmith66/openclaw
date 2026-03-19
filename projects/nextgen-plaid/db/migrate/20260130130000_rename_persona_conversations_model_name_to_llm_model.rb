class RenamePersonaConversationsModelNameToLlmModel < ActiveRecord::Migration[7.1]
  def change
    return unless column_exists?(:persona_conversations, :model_name)

    rename_column :persona_conversations, :model_name, :llm_model
  end
end
