class NullifyPlaidApiResponsesPlaidItemFk < ActiveRecord::Migration[8.0]
  def up
    change_column_null :plaid_api_responses, :plaid_item_id, true

    remove_foreign_key :plaid_api_responses, :plaid_items
    add_foreign_key :plaid_api_responses, :plaid_items, on_delete: :nullify
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely restore NOT NULL plaid_api_responses.plaid_item_id once rows may have been nullified"
  end
end
