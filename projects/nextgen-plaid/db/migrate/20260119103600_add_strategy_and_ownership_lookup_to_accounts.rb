class AddStrategyAndOwnershipLookupToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :asset_strategy, :string, default: "unknown", null: false

    add_reference :accounts,
                  :ownership_lookup,
                  null: true,
                  index: true,
                  foreign_key: { to_table: :ownership_lookups, on_delete: :restrict }
  end
end
