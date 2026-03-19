class AddRetryTrackingToPlaidItems < ActiveRecord::Migration[7.1]
  def change
    add_column :plaid_items, :retry_count, :integer, null: false, default: 0
    add_column :plaid_items, :last_retry_at, :datetime

    add_index :plaid_items, :last_retry_at
  end
end
