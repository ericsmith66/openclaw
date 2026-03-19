#!/bin/bash

# Epic-7 Investment Transaction Validation Script
# Run this on production server: 192.168.4.253
# Usage: ./validate_production_investments.sh

PRODUCTION_HOST="192.168.4.253"
DEPLOY_USER="deploy"
APP_PATH="/home/deploy/nextgen-plaid/current"

echo "========================================================================"
echo "INVESTMENT TRANSACTION VALIDATION - PRODUCTION"
echo "Host: $PRODUCTION_HOST"
echo "========================================================================"
echo ""

# Check if we should run locally or via SSH
if [ "$HOSTNAME" = "nextgen-plaid-prod" ] || [ -d "$APP_PATH" ]; then
  echo "Running locally on production server..."
  cd "$APP_PATH"
  RUN_PREFIX="RAILS_ENV=production bundle exec rails runner"
else
  echo "Running via SSH to $PRODUCTION_HOST..."
  RUN_PREFIX="ssh $DEPLOY_USER@$PRODUCTION_HOST 'cd $APP_PATH && RAILS_ENV=production bundle exec rails runner'"
fi

echo ""
echo "1. Basic Transaction Counts"
echo "----------------------------------------------------------------------"
eval "$RUN_PREFIX 'puts \"Total: #{Transaction.count}\"'"
eval "$RUN_PREFIX 'puts \"InvestmentTransaction: #{InvestmentTransaction.count}\"'"
eval "$RUN_PREFIX 'puts \"CreditTransaction: #{CreditTransaction.count}\"'"
eval "$RUN_PREFIX 'puts \"RegularTransaction: #{RegularTransaction.count}\"'"

echo ""
echo "2. Investment Accounts"
echo "----------------------------------------------------------------------"
eval "$RUN_PREFIX 'puts Account.where(plaid_account_type: \"investment\").count.to_s + \" investment accounts\"'"

echo ""
echo "3. Transactions from Investment Accounts"
echo "----------------------------------------------------------------------"
eval "$RUN_PREFIX '
  inv_accounts = Account.where(plaid_account_type: \"investment\").pluck(:id)
  total = Transaction.unscoped.where(account_id: inv_accounts).count
  as_inv = Transaction.unscoped.where(account_id: inv_accounts, type: \"InvestmentTransaction\").count
  as_reg = Transaction.unscoped.where(account_id: inv_accounts, type: \"RegularTransaction\").count
  puts \"Total from inv accounts: #{total}\"
  puts \"Typed as InvestmentTransaction: #{as_inv}\"
  puts \"Typed as RegularTransaction: #{as_reg}\"
  if as_reg > 0
    puts \"\"
    puts \"⚠️  WARNING: #{as_reg} transactions need reclassification!\"
    puts \"Run: RAILS_ENV=production bundle exec rails transactions:backfill_sti\"
  end
'"

echo ""
echo "4. Investment Transaction Fields"
echo "----------------------------------------------------------------------"
eval "$RUN_PREFIX '
  puts \"Has investment_transaction_id: #{Transaction.unscoped.where.not(investment_transaction_id: nil).count}\"
  puts \"Has investment_type: #{Transaction.unscoped.where.not(investment_type: nil).count}\"
  puts \"Has security_id: #{Transaction.unscoped.where.not(security_id: nil).count}\"
'"

echo ""
echo "5. Sample Investment Transactions"
echo "----------------------------------------------------------------------"
eval "$RUN_PREFIX '
  sample = InvestmentTransaction.limit(3)
  if sample.any?
    sample.each do |t|
      puts \"#{t.date} | #{t.name} | #{t.amount} | #{t.subtype} | #{t.account&.name}\"
    end
  else
    puts \"No InvestmentTransaction records found!\"
  end
'"

echo ""
echo "========================================================================"
echo "Validation complete."
echo "========================================================================"
echo ""
echo "Next steps:"
echo "  - If InvestmentTransaction count is 0 but investment accounts exist,"
echo "    run: RAILS_ENV=production bundle exec rails transactions:backfill_sti"
echo ""
echo "  - For full diagnostic report, run:"
echo "    RAILS_ENV=production bundle exec rails transactions:debug_sync"
