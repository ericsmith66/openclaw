class SetAllPlaidItemsStatusToGood < ActiveRecord::Migration[8.1]
  class PlaidItem < ApplicationRecord
    self.table_name = "plaid_items"
  end

  def up
    now = Time.current
    PlaidItem.update_all(
      status: "good",
      reauth_attempts: 0,
      last_error: nil,
      updated_at: now
    )
  end

  def down
    # no-op (data backfill)
  end
end
