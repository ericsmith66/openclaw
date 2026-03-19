class AddRetryCountAndLastErrorToTasks < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:tasks, :retry_count)
      add_column :tasks, :retry_count, :integer, default: 0
    end

    unless column_exists?(:tasks, :last_error)
      add_column :tasks, :last_error, :text
    end
  end
end
