class BackfillTransactionStiType < ActiveRecord::Migration[8.1]
  class AccountRow < ApplicationRecord
    self.table_name = "accounts"
  end

  class TransactionRow < ApplicationRecord
    self.table_name = "transactions"
    # Prevent STI during the backfill itself; we are writing STI class names.
    self.inheritance_column = :_type_disabled
  end

  def up
    unless AccountRow.column_names.include?("plaid_account_type")
      raise "PRD-0160.01 must be deployed first! Run Account STI migrations before Transaction STI."
    end

    orphaned_count = TransactionRow.unscoped
      .where.not(account_id: nil)
      .where.not(account_id: AccountRow.select(:id))
      .where(deleted_at: nil)
      .count
    raise "Found #{orphaned_count} orphaned transactions" if orphaned_count.positive?

    invalid_dividend_count = TransactionRow.unscoped
      .where.not(dividend_type: nil)
      .where(investment_transaction_id: nil, investment_type: nil)
      .where(deleted_at: nil)
      .count
    raise "Found #{invalid_dividend_count} transactions with dividend_type but no investment data" if invalid_dividend_count.positive?

    # NOTE: `type` must be present for *all* rows before we can add a NOT NULL
    # constraint (including soft-deleted rows).
    TransactionRow.unscoped.in_batches(of: 1000) do |batch|
      ids = batch.pluck(:id)
      next if ids.empty?

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
        WHERE id IN (#{ids.join(',')})
          AND type IS NULL
        ;
      SQL
    end
  end

  def down
    TransactionRow.unscoped.update_all(type: nil)
  end
end
