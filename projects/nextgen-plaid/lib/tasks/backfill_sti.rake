namespace :transactions do
  desc "Backfill STI types for investment and credit transactions"
  task backfill_sti: :environment do
    puts "Starting STI type backfill..."
    puts ""

    updated_count = 0
    skipped_count = 0
    error_count = 0

    Transaction.unscoped.includes(account: :plaid_item).find_each do |txn|
      # Skip transactions without accounts
      unless txn.account
        skipped_count += 1
        next
      end

      # Determine correct type based on account type
      correct_type = if txn.investment_transaction_id.present? || txn.investment_type.present?
                       "InvestmentTransaction"
      else
                       case txn.account.plaid_account_type
                       when "investment"
                         "InvestmentTransaction"
                       when "credit"
                         "CreditTransaction"
                       else
                         "RegularTransaction"
                       end
      end

      # Update if type is different
      if txn.type != correct_type
        begin
          txn.update_column(:type, correct_type)
          updated_count += 1
          puts "Updated transaction #{txn.id}: #{txn.type} -> #{correct_type}" if updated_count % 100 == 0
        rescue => e
          error_count += 1
          puts "ERROR updating transaction #{txn.id}: #{e.message}"
        end
      else
        skipped_count += 1
      end
    end

    puts ""
    puts "=" * 80
    puts "Backfill complete!"
    puts "  Updated: #{updated_count}"
    puts "  Skipped (already correct): #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts ""
    puts "Final counts:"
    puts "  RegularTransaction: #{RegularTransaction.count}"
    puts "  InvestmentTransaction: #{InvestmentTransaction.count}"
    puts "  CreditTransaction: #{CreditTransaction.count}"
    puts "=" * 80
  end
end
