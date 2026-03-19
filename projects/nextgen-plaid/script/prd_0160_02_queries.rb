conn = ActiveRecord::Base.connection

q1 = <<~SQL
  SELECT
    CASE
      WHEN investment_transaction_id IS NOT NULL THEN 'InvestmentTransaction'
      WHEN investment_type IS NOT NULL THEN 'InvestmentTransaction'
      WHEN account_id IS NULL THEN 'RegularTransaction'
      WHEN account_id IN (
        SELECT id FROM accounts
        WHERE plaid_account_type = 'credit' OR subtype IN ('credit card', 'paypal')
      ) THEN 'CreditTransaction'
      ELSE 'RegularTransaction'
    END AS proposed_type,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
  FROM transactions
  WHERE deleted_at IS NULL
  GROUP BY proposed_type;
SQL

q2 = <<~SQL
  SELECT COUNT(*) as ambiguous_count,
         ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions WHERE deleted_at IS NULL), 2) as percentage
  FROM transactions t
  JOIN accounts a ON t.account_id = a.id
  WHERE (t.investment_type IS NOT NULL OR t.investment_transaction_id IS NOT NULL)
    AND (a.plaid_account_type = 'credit' OR a.subtype IN ('credit card', 'paypal'))
    AND t.deleted_at IS NULL;
SQL

q3 = <<~SQL
  SELECT COUNT(*) as orphaned_count
  FROM transactions
  WHERE account_id IS NOT NULL
    AND account_id NOT IN (SELECT id FROM accounts)
    AND deleted_at IS NULL;
SQL

q4 = <<~SQL
  SELECT COUNT(*) as invalid_dividend_count
  FROM transactions
  WHERE dividend_type IS NOT NULL
    AND investment_transaction_id IS NULL
    AND investment_type IS NULL
    AND deleted_at IS NULL;
SQL

puts "-- proposed_type distribution"
pp conn.exec_query(q1).to_a

puts "-- ambiguous_count"
pp conn.exec_query(q2).to_a

puts "-- orphaned_count"
pp conn.exec_query(q3).to_a

puts "-- invalid_dividend_count"
pp conn.exec_query(q4).to_a
