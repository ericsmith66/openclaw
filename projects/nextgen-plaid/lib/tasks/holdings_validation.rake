# frozen_string_literal: true

require "csv"

namespace :holdings do
  desc "Validate that tax-lot positions CSV matches DB holdings by account (Usage: rake holdings:validate_positions_csv[file_path,user_id])"
  task :validate_positions_csv, [ :file_path, :user_id ] => :environment do |_t, args|
    begin
    file_path = args[:file_path] || ENV["FILE"] || Rails.root.join("tmp", "Position.csv").to_s
    user_id = args[:user_id] || ENV["USER_ID"]

    ignored_tickers = [ "0USD" ].freeze

    unless File.exist?(file_path)
      puts "Error: file not found: #{file_path}"
      puts "Usage: rake holdings:validate_positions_csv['/path/to/Position.csv',user_id]"
      puts "Or set FILE=/path/to/Position.csv and USER_ID=..."
      exit 1
    end

    unless user_id.present?
      puts "Error: user_id is required"
      puts "Usage: rake holdings:validate_positions_csv['/path/to/Position.csv',user_id]"
      puts "Or set USER_ID environment variable"
      exit 1
    end

    user = User.find_by(id: user_id)
    unless user
      puts "Error: User with id #{user_id} not found"
      exit 1
    end

    # Load accounts for user and map by last-4 mask.
    accounts = Account.joins(:plaid_item).where(plaid_items: { user_id: user.id })
    accounts_by_last4 = accounts.group_by(&:mask)

    # Parse CSV and aggregate tax lots by account last4 + ticker.
    # We aggregate quantity, value, and cost so you can sanity-check totals.
    csv_positions = Hash.new do |h, k|
      h[k] = Hash.new { |hh, kk| hh[kk] = { qty: 0.0, value: 0.0, cost: 0.0 } }
    end
    missing_last4_rows = 0

    CSV.foreach(file_path, headers: true) do |row|
      account_number = row["Account number"].to_s
      ticker = row["Ticker"].to_s.strip
      qty_raw = row["Quantity"].to_s
      value_raw = row["Value"].to_s
      cost_raw = row["Cost"].to_s

      # Account number format is like "D...5009" → last4 = "5009".
      last4 = account_number[/([0-9]{4})\z/, 1]
      if last4.blank?
        missing_last4_rows += 1
        next
      end

      next if ticker.blank?
      next if ignored_tickers.include?(ticker)

      qty = qty_raw.delete(",").to_f
      value = value_raw.delete(",").to_f
      cost = cost_raw.delete(",").to_f

      csv_positions[last4][ticker][:qty] += qty
      csv_positions[last4][ticker][:value] += value
      csv_positions[last4][ticker][:cost] += cost
    end

    # Aggregate DB holdings by account and symbol/ticker.
    # We aggregate quantity, market_value, and cost_basis.
    db_positions_by_account_id = Hash.new do |h, k|
      h[k] = Hash.new { |hh, kk| hh[kk] = { qty: 0.0, value: 0.0, cost: 0.0 } }
    end
    holdings = Holding.where(account_id: accounts.select(:id))

    holdings.find_each do |h|
      key = h.symbol.presence || h.ticker_symbol.presence
      next if key.blank?
      next if ignored_tickers.include?(key)
      db_positions_by_account_id[h.account_id][key][:qty] += h.quantity.to_f
      db_positions_by_account_id[h.account_id][key][:value] += h.market_value.to_f
      db_positions_by_account_id[h.account_id][key][:cost] += h.cost_basis.to_f
    end

    mismatches = 0
    warnings = 0

    cost_diff_threshold = 10.0

    grand_csv_cost = 0.0
    grand_db_cost = 0.0
    grand_csv_value = 0.0
    grand_db_value = 0.0

    puts "Validating holdings vs CSV positions"
    puts "  user_id=#{user.id} email=#{user.email}"
    puts "  file=#{file_path}"
    puts "  csv_accounts=#{csv_positions.keys.size}"
    puts "  db_accounts=#{accounts.count}"
    puts "  csv_rows_missing_last4=#{missing_last4_rows}"
    puts ""

    csv_positions.keys.sort.each do |last4|
      candidate_accounts = accounts_by_last4[last4] || []

      if candidate_accounts.empty?
        warnings += 1
        puts "WARN: CSV account last4=#{last4} not found in DB accounts for user"
        next
      end

      if candidate_accounts.size > 1
        warnings += 1
        ids = candidate_accounts.map(&:id).join(",")
        puts "WARN: last4 collision last4=#{last4} accounts=#{ids} (will validate each account separately)"
      end

      candidate_accounts.each do |account|
        csv_by_ticker = csv_positions[last4]
        db_by_ticker = db_positions_by_account_id[account.id]

        all_tickers = (csv_by_ticker.keys + db_by_ticker.keys).uniq.sort
        all_tickers -= ignored_tickers
        account_mismatches = []

        csv_total_qty = 0.0
        csv_total_value = 0.0
        csv_total_cost = 0.0
        csv_by_ticker.each_value do |v|
          csv_total_qty += v[:qty].to_f
          csv_total_value += v[:value].to_f
          csv_total_cost += v[:cost].to_f
        end

        db_total_qty = 0.0
        db_total_value = 0.0
        db_total_cost = 0.0
        db_by_ticker.each_value do |v|
          db_total_qty += v[:qty].to_f
          db_total_value += v[:value].to_f
          db_total_cost += v[:cost].to_f
        end

        all_tickers.each do |ticker|
          csv_qty = csv_by_ticker[ticker][:qty].to_f
          csv_value = csv_by_ticker[ticker][:value].to_f
          csv_cost = csv_by_ticker[ticker][:cost].to_f
          db_qty = db_by_ticker[ticker][:qty].to_f
          db_value = db_by_ticker[ticker][:value].to_f
          db_cost = db_by_ticker[ticker][:cost].to_f

          # Only show per-symbol lines where cost basis differs materially; keep the per-account
          # totals output below for context.
          next unless (csv_cost - db_cost).abs > cost_diff_threshold

          account_mismatches << [ ticker, csv_qty, db_qty, csv_value, db_value, csv_cost, db_cost ]
        end

        next if account_mismatches.empty?

        grand_csv_cost += csv_total_cost
        grand_db_cost += db_total_cost
        grand_csv_value += csv_total_value
        grand_db_value += db_total_value

        mismatches += 1
        puts "\nMismatch for account id=#{account.id} name=\"#{account.name}\" mask=#{account.mask}"
        puts "  totals: csv_qty=#{csv_total_qty} db_qty=#{db_total_qty} csv_value=#{csv_total_value.round(2)} db_value=#{db_total_value.round(2)} csv_cost=#{csv_total_cost.round(2)} db_cost=#{db_total_cost.round(2)}"

        puts "  NOTE: showing only tickers where |csv_cost - db_cost| > $#{cost_diff_threshold.to_i}"

        # Do not truncate findings: print all mismatches for this account.
        account_mismatches.each do |ticker, csv_qty, db_qty, csv_value, db_value, csv_cost, db_cost|
          # Keep columns aligned for scanning.
          puts "  ticker=#{ticker.ljust(12)} csv_qty=#{csv_qty.to_s.ljust(12)} db_qty=#{db_qty.to_s.ljust(12)} csv_value=#{csv_value.round(2).to_s.ljust(12)} db_value=#{db_value.round(2).to_s.ljust(12)} csv_cost=#{csv_cost.round(2).to_s.ljust(12)} db_cost=#{db_cost.round(2)}"
        end
      end
    end

    # Summarize cost basis by account (totals), plus a grand total.
    puts "\nCost basis summary (CSV vs DB) by account"
    puts "  NOTE: accounts are matched by last4 mask from CSV 'Account number' (e.g. D...5009 → 5009)"

    csv_positions.keys.sort.each do |last4|
      candidate_accounts = accounts_by_last4[last4] || []
      next if candidate_accounts.empty?

      # CSV totals for this last4
      csv_by_ticker = csv_positions[last4]
      csv_cost_total = csv_by_ticker.values.sum { |v| v[:cost].to_f }
      csv_value_total = csv_by_ticker.values.sum { |v| v[:value].to_f }

      candidate_accounts.each do |account|
        db_by_ticker = db_positions_by_account_id[account.id]
        db_cost_total = db_by_ticker.values.sum { |v| v[:cost].to_f }
        db_value_total = db_by_ticker.values.sum { |v| v[:value].to_f }

        puts "  account id=#{account.id.to_s.ljust(6)} mask=#{account.mask} name=\"#{account.name}\" csv_cost=#{csv_cost_total.round(2).to_s.ljust(14)} db_cost=#{db_cost_total.round(2).to_s.ljust(14)} csv_value=#{csv_value_total.round(2).to_s.ljust(14)} db_value=#{db_value_total.round(2)}"
      end
    end

    puts "\nSummary:"
    puts "  mismatched_accounts=#{mismatches}"
    puts "  warnings=#{warnings}"
    puts "  grand_totals: csv_cost=#{grand_csv_cost.round(2)} db_cost=#{grand_db_cost.round(2)} csv_value=#{grand_csv_value.round(2)} db_value=#{grand_db_value.round(2)}"

    exit(mismatches.zero? ? 0 : 2)
    rescue Errno::EPIPE
      # If output is being piped (e.g., to `head`) and the consumer closes early,
      # Ruby raises EPIPE on STDOUT writes. Treat that as a normal early-exit.
      exit 0
    end
  end
end
