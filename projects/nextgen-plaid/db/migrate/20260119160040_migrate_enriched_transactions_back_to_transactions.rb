class MigrateEnrichedTransactionsBackToTransactions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE transactions t
      SET
        merchant_name = COALESCE(t.merchant_name, et.merchant_name),
        logo_url = COALESCE(t.logo_url, et.logo_url),
        website = COALESCE(t.website, et.website)
      FROM enriched_transactions et
      WHERE et.transaction_id = t.id
        AND (
          et.merchant_name IS NOT NULL OR
          et.logo_url IS NOT NULL OR
          et.website IS NOT NULL
        )
    SQL
  end

  def down
    # no-op: legacy table still exists and may already contain data
  end
end
