class AddResultAndErrorMessageToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :result, :text
    add_column :tasks, :error_message, :text
  end
end
