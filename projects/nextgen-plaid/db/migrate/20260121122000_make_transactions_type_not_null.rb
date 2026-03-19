class MakeTransactionsTypeNotNull < ActiveRecord::Migration[8.1]
  class TransactionRow < ApplicationRecord
    self.table_name = "transactions"
    self.inheritance_column = :_type_disabled
  end

  def up
    # `change_column_null` checks all rows; ensure *no* transactions have NULL `type`
    # (including soft-deleted rows) before applying the constraint.
    #
    # IMPORTANT: this migration must be safe to run on databases where the prior
    # backfill migration may have already run with older logic. So we attempt a
    # deterministic backfill for any remaining NULLs here.
    TransactionRow.connection.execute(<<~SQL)
      UPDATE transactions
      SET type = CASE
        WHEN investment_transaction_id IS NOT NULL THEN 'InvestmentTransaction'
        WHEN investment_type IS NOT NULL THEN 'InvestmentTransaction'
        WHEN account_id IS NULL THEN 'RegularTransaction'
        WHEN account_id IN (
          SELECT id FROM accounts
          WHERE plaid_account_type = 'credit'
             OR subtype IN ('credit card', 'paypal')
        ) THEN 'CreditTransaction'
        ELSE 'RegularTransaction'
      END
      WHERE type IS NULL
      ;
    SQL

    null_count = TransactionRow.unscoped.where(type: nil).count
    raise "Found #{null_count} transactions with NULL type" if null_count.positive?

    change_column_null :transactions, :type, false
  end

  def down
    change_column_null :transactions, :type, true
  end
end
