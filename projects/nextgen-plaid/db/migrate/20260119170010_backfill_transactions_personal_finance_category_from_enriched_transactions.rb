class BackfillTransactionsPersonalFinanceCategoryFromEnrichedTransactions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE transactions t
      SET personal_finance_category = et.personal_finance_category
      FROM enriched_transactions et
      WHERE et.transaction_id = t.id
        AND et.personal_finance_category IS NOT NULL
        AND (t.personal_finance_category IS NULL OR t.personal_finance_category = '')
    SQL
  end

  def down
    # no-op
  end
end
