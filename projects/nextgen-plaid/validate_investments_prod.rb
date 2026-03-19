#!/usr/bin/env ruby
# Epic-7 Investment Transaction Validation Script
# Run on production: RAILS_ENV=production bundle exec rails runner validate_investments_prod.rb

puts "=" * 80
puts "INVESTMENT TRANSACTION VALIDATION - PRODUCTION"
puts "Host: #{`hostname`.strip rescue 'unknown'}"
puts "Time: #{Time.current}"
puts "=" * 80
puts ""

begin
  # 1. Basic counts
  puts "1. TRANSACTION COUNTS"
  puts "-" * 80
  puts "  Total transactions: #{Transaction.count}"
  puts "  InvestmentTransaction: #{InvestmentTransaction.count}"
  puts "  CreditTransaction: #{CreditTransaction.count}"
  puts "  RegularTransaction: #{RegularTransaction.count}"
  puts ""

  # 2. Investment accounts
  puts "2. INVESTMENT ACCOUNTS"
  puts "-" * 80
  inv_accounts = Account.where(plaid_account_type: 'investment')
  puts "  Investment accounts: #{inv_accounts.count}"

  if inv_accounts.any?
    inv_accounts.limit(5).each do |acct|
      txn_count = acct.transactions.count
      inv_txn_count = acct.transactions.where(type: 'InvestmentTransaction').count
      puts "    - #{acct.name}"
      puts "      Transactions: #{txn_count} (#{inv_txn_count} as InvestmentTransaction)"
      puts "      Latest: #{acct.transactions.maximum(:date) || 'none'}"
    end
  else
    puts "  ⚠️  No investment accounts found!"
  end
  puts ""

  # 3. Transactions from investment accounts by type
  puts "3. TRANSACTIONS FROM INVESTMENT ACCOUNTS"
  puts "-" * 80
  inv_account_ids = inv_accounts.pluck(:id)

  if inv_account_ids.any?
    total = Transaction.unscoped.where(account_id: inv_account_ids).count
    as_inv = Transaction.unscoped.where(account_id: inv_account_ids, type: 'InvestmentTransaction').count
    as_reg = Transaction.unscoped.where(account_id: inv_account_ids, type: 'RegularTransaction').count
    as_cred = Transaction.unscoped.where(account_id: inv_account_ids, type: 'CreditTransaction').count

    puts "  Total: #{total}"
    puts "  As InvestmentTransaction: #{as_inv} (#{(as_inv.to_f / total * 100).round(1)}%)"
    puts "  As RegularTransaction: #{as_reg} (#{(as_reg.to_f / total * 100).round(1)}%)"
    puts "  As CreditTransaction: #{as_cred}"
    puts ""

    if as_reg > 0 || as_cred > 0
      puts "  ⚠️  WARNING: #{as_reg + as_cred} transactions need reclassification!"
      puts "  Action: Run STI backfill task"
      puts "    RAILS_ENV=production bundle exec rails transactions:backfill_sti"
      puts ""
    end
  else
    puts "  No investment accounts to check."
    puts ""
  end

  # 4. Investment-specific fields
  puts "4. INVESTMENT TRANSACTION FIELDS"
  puts "-" * 80
  puts "  Has investment_transaction_id: #{Transaction.unscoped.where.not(investment_transaction_id: nil).count}"
  puts "  Has investment_type: #{Transaction.unscoped.where.not(investment_type: nil).count}"
  puts "  Has security_id: #{Transaction.unscoped.where.not(security_id: nil).count}"
  puts "  Has subtype: #{Transaction.unscoped.where.not(subtype: nil).count}"
  puts ""

  # 5. Sample InvestmentTransaction records
  puts "5. SAMPLE INVESTMENTTRANSACTION RECORDS"
  puts "-" * 80
  samples = InvestmentTransaction.order(date: :desc).limit(5)

  if samples.any?
    samples.each do |txn|
      puts "  Date: #{txn.date}"
      puts "  Name: #{txn.name}"
      puts "  Amount: #{txn.amount}"
      puts "  Subtype: #{txn.subtype}"
      puts "  Security: #{txn.security_name || txn.security_id || 'N/A'}"
      puts "  Account: #{txn.account&.name}"
      puts "  ---"
    end
  else
    puts "  ❌ No InvestmentTransaction records found!"
    puts ""

    # Check if there are transactions that should be InvestmentTransaction
    if inv_account_ids.any?
      mistyped = Transaction.unscoped
                            .where(account_id: inv_account_ids)
                            .where(type: 'RegularTransaction')
                            .order(date: :desc)
                            .limit(3)

      if mistyped.any?
        puts "  Found mistyped transactions from investment accounts:"
        mistyped.each do |txn|
          puts "    ID: #{txn.id} | #{txn.date} | #{txn.amount} | #{txn.name}"
        end
        puts ""
      end
    end
  end
  puts ""

  # 6. Summary and recommendations
  puts "6. SUMMARY & RECOMMENDATIONS"
  puts "-" * 80

  inv_count = InvestmentTransaction.count
  inv_acct_count = inv_accounts.count

  if inv_acct_count == 0
    puts "  ✅ No investment accounts - this is expected if none are linked."
  elsif inv_count == 0
    puts "  ❌ ISSUE: Investment accounts exist but no InvestmentTransaction records!"
    puts ""
    puts "  ROOT CAUSE: Transactions not classified with correct STI type"
    puts ""
    puts "  FIX:"
    puts "    1. Run: RAILS_ENV=production bundle exec rails transactions:backfill_sti"
    puts "    2. Verify: RAILS_ENV=production bundle exec rails runner validate_investments_prod.rb"
    puts "    3. Test: Visit /transactions/investment in browser"
  elsif inv_count < 10
    puts "  ⚠️  WARNING: Only #{inv_count} InvestmentTransaction records found."
    puts "  This may be normal if the account is new or has few transactions."
  else
    puts "  ✅ #{inv_count} InvestmentTransaction records found across #{inv_acct_count} accounts."
    puts "  Data appears healthy. Verify UI at /transactions/investment"
  end

  puts ""
  puts "=" * 80
  puts "Validation complete."
  puts "=" * 80

rescue => e
  puts ""
  puts "=" * 80
  puts "ERROR DURING VALIDATION"
  puts "=" * 80
  puts e.class.name
  puts e.message
  puts ""
  puts "Backtrace:"
  puts e.backtrace.first(10).join("\n")
end
