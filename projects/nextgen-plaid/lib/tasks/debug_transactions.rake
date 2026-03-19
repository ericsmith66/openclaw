namespace :transactions do
  desc "Debug transaction sync status and data availability"
  task debug_sync: :environment do
    puts "=" * 80
    puts "TRANSACTION SYNC STATUS REPORT"
    puts "=" * 80
    puts ""

    # Latest transaction date
    latest_date = Transaction.maximum(:date)
    puts "Latest transaction date: #{latest_date || 'NONE'}"
    puts "Days since last transaction: #{latest_date ? (Date.current - latest_date).to_i : 'N/A'}"
    puts ""

    # Sync logs
    puts "Recent sync logs:"
    SyncLog.where(job_type: "sync_transactions")
           .order(created_at: :desc)
           .limit(5)
           .each do |log|
      puts "  #{log.created_at.strftime('%Y-%m-%d %H:%M')} | #{log.status} | #{log.error_message || 'OK'}"
    end
    puts ""

    # Plaid items status
    puts "Plaid items status:"
    PlaidItem.find_each do |item|
      puts "  Item #{item.id}: #{item.status || 'unknown'} | Error: #{item.error_code || 'none'} | Updated: #{item.updated_at.strftime('%Y-%m-%d %H:%M')}"
    end
    puts ""

    # Transaction counts
    puts "Transaction counts:"
    puts "  Total (unscoped): #{Transaction.unscoped.count}"
    puts "  Active (not deleted): #{Transaction.count}"
    puts "  Pending: #{Transaction.where(pending: true).count}"
    puts ""

    # STI type breakdown
    puts "STI Type Breakdown:"
    puts "  RegularTransaction: #{RegularTransaction.count}"
    puts "  InvestmentTransaction: #{InvestmentTransaction.count}"
    puts "  CreditTransaction: #{CreditTransaction.count}"
    puts "  NULL type: #{Transaction.unscoped.where(type: nil).count}"
    puts ""

    # Investment-related transactions
    puts "Investment-Related Transactions:"
    puts "  Has investment_transaction_id: #{Transaction.unscoped.where.not(investment_transaction_id: nil).count}"
    puts "  Has investment_type: #{Transaction.unscoped.where.not(investment_type: nil).count}"
    puts "  Has security_id: #{Transaction.unscoped.where.not(security_id: nil).count}"
    puts "  From investment accounts: #{Transaction.unscoped.joins(:account).where(accounts: { plaid_account_type: 'investment' }).count}"
    puts ""

    # Credit transactions
    puts "Credit-Related Transactions:"
    puts "  From credit accounts: #{Transaction.unscoped.joins(:account).where(accounts: { plaid_account_type: 'credit' }).count}"
    puts ""

    # Transfer transactions
    puts "Transfer Transactions:"
    transfer_count = Transaction.where("personal_finance_category_label ILIKE ?", "TRANSFER%").count
    puts "  Labeled as TRANSFER%: #{transfer_count}"
    if transfer_count > 0
      puts "  Sample labels:"
      Transaction.where("personal_finance_category_label ILIKE ?", "TRANSFER%")
                 .distinct
                 .pluck(:personal_finance_category_label)
                 .first(10)
                 .each { |label| puts "    - #{label}" }
    end
    puts ""

    puts "=" * 80
    puts "Report complete. Run 'rails transactions:backfill_sti' if needed."
    puts "=" * 80
  end
end
