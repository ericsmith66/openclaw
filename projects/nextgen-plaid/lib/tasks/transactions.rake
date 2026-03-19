# frozen_string_literal: true

namespace :transactions do
  desc "Backfill STI types for existing transactions based on account type"
  task backfill_sti_types: :environment do
    total_updated = 0
    total_skipped = 0

    puts "Starting STI backfill for transactions..."

    Transaction.find_in_batches(batch_size: 1000) do |batch|
      batch.each do |txn|
        # Skip soft-deleted transactions (default_scope excludes them already)
        next if txn.deleted_at.present?

        # Only reclassify RegularTransaction rows
        next unless txn.type == "RegularTransaction"

        account = txn.account
        next unless account.present?

        new_type = if account.investment?
                     "InvestmentTransaction"
        elsif account.credit?
                     "CreditTransaction"
        else
                     nil
        end

        if new_type.present?
          txn.update_column(:type, new_type)
          total_updated += 1
          print "."
        else
          total_skipped += 1
        end
      end
    end

    puts "\nBackfill complete."
    puts "Updated: #{total_updated}"
    puts "Skipped: #{total_skipped}"
  end

  desc "Verify STI type completeness"
  task verify_sti_completeness: :environment do
    puts "Checking for misclassified transactions..."
    puts

    misclassified = Transaction
      .where(type: "RegularTransaction")
      .joins(:account)
      .where(accounts: { plaid_account_type: [ "investment", "credit" ] })

    if misclassified.any?
      puts "⚠️  Found #{misclassified.count} misclassified transactions:"
      puts
      misclassified.limit(10).each do |t|
        puts "  - Transaction #{t.id}: type=#{t.type}, account.plaid_account_type=#{t.account.plaid_account_type}"
      end
      puts
      puts "Run: rake transactions:backfill_sti_types"
      exit 1
    else
      puts "✅ All transactions correctly classified"
      puts "   - RegularTransaction count: #{Transaction.where(type: 'RegularTransaction').count}"
      puts "   - InvestmentTransaction count: #{Transaction.where(type: 'InvestmentTransaction').count}"
      puts "   - CreditTransaction count: #{Transaction.where(type: 'CreditTransaction').count}"
    end
  end
end
