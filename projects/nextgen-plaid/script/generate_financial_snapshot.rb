#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to generate financial snapshot for ericsmith66@me.com production accounts
# Usage: rails runner script/generate_financial_snapshot.rb

require 'json'

class FinancialSnapshotGenerator
  SNAPSHOT_DATE = Date.new(2026, 2, 28)
  TARGET_EMAIL = 'ericsmith66@me.com'
  OUTPUT_DIR = '/Users/ericsmith66/Documents/Taxes/Taxes 2025/data/json'
  OUTPUT_FILE = 'financial_snapshot_2026_02.json'
  SUMMARY_FILE = '/Users/ericsmith66/Documents/Taxes/Taxes 2025/data/FINANCIAL_SNAPSHOT_2026_02_SUMMARY.md'

  # Trust mapping from tax records
  TRUST_ACCOUNTS = {
    'Smith Family Revocable Trust' => [ '5000', '7008', '8006', '9004', '0007', '1005', '8004' ],
    'Smith Family Irrevocable Trust' => [ '7006', '6002' ],
    'Smith Descendants Irrevocable Trust' => [ '5009' ],
    'Jacob Smith Irrevocable Trust' => [ '1008', '2006', '5001' ],
    'Quinn Smith Irrevocable Trust' => [ '8008', '2003', '4009' ],
    'Individual - Angela' => [ '6001' ],
    'Individual - Eric' => [ '8007' ]
  }.freeze

  # Tax year 2025 income data for comparison
  TAX_2025_INCOME = 704_394

  def initialize
    @user = User.find_by(email: TARGET_EMAIL)
    raise "User #{TARGET_EMAIL} not found" unless @user

    puts "Found user: #{@user.email} (ID: #{@user.id})"
    @snapshot = {
      snapshot_date: SNAPSHOT_DATE.to_s,
      user_email: @user.email,
      generated_at: Time.current.iso8601,
      total_portfolio_value: 0,
      total_cost_basis: 0,
      total_unrealized_gains: 0,
      ytd_income_2026: {
        dividends: 0,
        interest: 0,
        capital_gains_distributions: 0,
        realized_capital_gains: 0,
        total: 0
      },
      accounts: [],
      trust_rollup: {},
      comparison_to_2025: {
        income_2025_full_year: TAX_2025_INCOME,
        income_2026_ytd: 0,
        projected_2026_annual: 0,
        growth_rate: '0%'
      }
    }
  end

  def generate
    puts "\n=== Gathering Account Data ==="
    gather_accounts

    puts "\n=== Calculating YTD Income ==="
    calculate_ytd_income

    puts "\n=== Creating Trust Rollup ==="
    create_trust_rollup

    puts "\n=== Calculating Comparison to 2025 ==="
    calculate_comparison

    puts "\n=== Saving Files ==="
    save_files

    puts "\n✅ Financial snapshot generated successfully!"
    puts "JSON file: #{File.join(OUTPUT_DIR, OUTPUT_FILE)}"
    puts "Summary file: #{SUMMARY_FILE}"
  end

  private

  def gather_accounts
    accounts = @user.plaid_items.includes(:accounts).flat_map(&:accounts)
    puts "Found #{accounts.count} total accounts"

    accounts.each do |account|
      account_data = build_account_data(account)
      @snapshot[:accounts] << account_data

      # Update totals
      @snapshot[:total_portfolio_value] += account_data[:current_balance].to_f
      @snapshot[:total_cost_basis] += account_data[:cost_basis].to_f
      @snapshot[:total_unrealized_gains] += account_data[:unrealized_gain_loss].to_f

      puts "  ✓ #{account.name} (#{account.mask || 'N/A'}) - Balance: $#{format_currency(account_data[:current_balance])}"
    end
  end

  def build_account_data(account)
    last4 = account.mask || extract_last_4(account.account_id)
    trust_owner = find_trust_owner(last4)

    # Get holdings for investment accounts
    top_holdings = []
    if account.investment?
      holdings = account.holdings.order(market_value: :desc).limit(5)
      top_holdings = holdings.map do |h|
        {
          symbol: h.ticker_symbol || h.security_id,
          shares: h.quantity.to_f.round(4),
          value: h.market_value.to_f.round(2),
          cost_basis: h.cost_basis.to_f.round(2)
        }
      end
    end

    # Calculate cost basis and unrealized gains from holdings
    cost_basis = account.investment? ? account.holdings.sum(:cost_basis).to_f : 0
    unrealized_gl = account.investment? ? account.holdings.sum(:unrealized_gl).to_f : 0

    {
      account_number_last4: last4,
      account_full_name: account.name,
      broker: determine_broker(account),
      trust_owner: trust_owner,
      account_type: account.plaid_account_type,
      current_balance: (account.current_balance || 0).to_f.round(2),
      cost_basis: cost_basis.round(2),
      unrealized_gain_loss: unrealized_gl.round(2),
      ytd_2026_income: calculate_account_ytd_income(account),
      top_holdings: top_holdings,
      transactions_ytd: calculate_transactions_ytd(account)
    }
  end

  def calculate_account_ytd_income(account)
    start_date = Date.new(2026, 1, 1)
    end_date = SNAPSHOT_DATE

    # Get income from transactions
    transactions = account.transactions.where(date: start_date..end_date)

    dividends = transactions.where("personal_finance_category_label LIKE ?", "%DIVIDEND%").sum(:amount).to_f.abs
    interest = transactions.where("personal_finance_category_label LIKE ?", "%INTEREST%").sum(:amount).to_f.abs
    capital_gains_dist = transactions.where("personal_finance_category_label LIKE ?", "%CAPITAL_GAINS%").sum(:amount).to_f.abs

    # Realized gains from investment transactions
    realized_gains = if account.investment?
      investment_txns = account.transactions.where(date: start_date..end_date, type: 'InvestmentTransaction')
      investment_txns.where("investment_transaction_type IN (?)", [ 'sell', 'buy' ]).sum(:amount).to_f
    else
      0
    end

    {
      dividends: dividends.round(2),
      interest: interest.round(2),
      capital_gains_distributions: capital_gains_dist.round(2),
      realized_capital_gains: realized_gains.round(2)
    }
  end

  def calculate_transactions_ytd(account)
    start_date = Date.new(2026, 1, 1)
    end_date = SNAPSHOT_DATE

    transactions = account.transactions.where(date: start_date..end_date)

    deposits = transactions.where("amount > 0").sum(:amount).to_f
    withdrawals = transactions.where("amount < 0").sum(:amount).to_f.abs
    trade_count = account.investment? ? transactions.where(type: 'InvestmentTransaction').count : 0

    {
      deposits: deposits.round(2),
      withdrawals: withdrawals.round(2),
      trade_count: trade_count
    }
  end

  def calculate_ytd_income
    @snapshot[:accounts].each do |acct|
      ytd = acct[:ytd_2026_income]
      @snapshot[:ytd_income_2026][:dividends] += ytd[:dividends]
      @snapshot[:ytd_income_2026][:interest] += ytd[:interest]
      @snapshot[:ytd_income_2026][:capital_gains_distributions] += ytd[:capital_gains_distributions]
      @snapshot[:ytd_income_2026][:realized_capital_gains] += ytd[:realized_capital_gains]
    end

    @snapshot[:ytd_income_2026][:total] =
      @snapshot[:ytd_income_2026][:dividends] +
      @snapshot[:ytd_income_2026][:interest] +
      @snapshot[:ytd_income_2026][:capital_gains_distributions] +
      @snapshot[:ytd_income_2026][:realized_capital_gains]

    # Round all values
    @snapshot[:ytd_income_2026].transform_values! { |v| v.round(2) }

    puts "YTD 2026 Income: $#{format_currency(@snapshot[:ytd_income_2026][:total])}"
  end

  def create_trust_rollup
    TRUST_ACCOUNTS.each do |trust_name, account_masks|
      trust_accounts = @snapshot[:accounts].select { |a| account_masks.include?(a[:account_number_last4]) }

      next if trust_accounts.empty?

      total_balance = trust_accounts.sum { |a| a[:current_balance] }
      ytd_income = trust_accounts.sum do |a|
        ytd = a[:ytd_2026_income]
        ytd[:dividends] + ytd[:interest] + ytd[:capital_gains_distributions] + ytd[:realized_capital_gains]
      end

      @snapshot[:trust_rollup][trust_name] = {
        total_balance: total_balance.round(2),
        ytd_income: ytd_income.round(2),
        account_count: trust_accounts.count,
        accounts: account_masks
      }

      puts "  #{trust_name}: $#{format_currency(total_balance)} (#{trust_accounts.count} accounts)"
    end
  end

  def calculate_comparison
    ytd_income = @snapshot[:ytd_income_2026][:total]

    # Calculate days elapsed and project annual
    days_elapsed = (SNAPSHOT_DATE - Date.new(2026, 1, 1)).to_i + 1
    days_in_year = Date.new(2026, 12, 31).yday

    projected_annual = if days_elapsed > 0
      (ytd_income / days_elapsed) * days_in_year
    else
      0
    end

    growth_rate = if TAX_2025_INCOME > 0
      ((projected_annual - TAX_2025_INCOME) / TAX_2025_INCOME * 100).round(2)
    else
      0
    end

    @snapshot[:comparison_to_2025][:income_2026_ytd] = ytd_income.round(2)
    @snapshot[:comparison_to_2025][:projected_2026_annual] = projected_annual.round(2)
    @snapshot[:comparison_to_2025][:growth_rate] = "#{growth_rate}%"

    puts "Projected 2026 Annual: $#{format_currency(projected_annual)} (#{growth_rate}% vs 2025)"
  end

  def save_files
    # Ensure directory exists
    FileUtils.mkdir_p(OUTPUT_DIR)

    # Save JSON
    json_path = File.join(OUTPUT_DIR, OUTPUT_FILE)
    File.write(json_path, JSON.pretty_generate(@snapshot))
    puts "  ✓ JSON saved to #{json_path}"

    # Save summary markdown
    save_summary_markdown
    puts "  ✓ Summary saved to #{SUMMARY_FILE}"
  end

  def save_summary_markdown
    md = <<~MARKDOWN
      # Financial Snapshot Summary - February 2026

      **Generated:** #{Time.current.strftime('%B %d, %Y at %I:%M %p')}#{'  '}
      **User:** #{@user.email}#{'  '}
      **Snapshot Date:** #{SNAPSHOT_DATE.strftime('%B %d, %Y')}

      ---

      ## 📊 Portfolio Overview

      | Metric | Value |
      |--------|-------|
      | **Total Portfolio Value** | $#{format_currency(@snapshot[:total_portfolio_value])} |
      | **Total Cost Basis** | $#{format_currency(@snapshot[:total_cost_basis])} |
      | **Total Unrealized Gains** | $#{format_currency(@snapshot[:total_unrealized_gains])} |
      | **Gain %** | #{calculate_gain_percentage}% |

      ---

      ## 💰 2026 YTD Income (Jan 1 - Feb 28)

      | Category | Amount |
      |----------|--------|
      | Dividends | $#{format_currency(@snapshot[:ytd_income_2026][:dividends])} |
      | Interest | $#{format_currency(@snapshot[:ytd_income_2026][:interest])} |
      | Capital Gains Distributions | $#{format_currency(@snapshot[:ytd_income_2026][:capital_gains_distributions])} |
      | Realized Capital Gains | $#{format_currency(@snapshot[:ytd_income_2026][:realized_capital_gains])} |
      | **Total YTD Income** | **$#{format_currency(@snapshot[:ytd_income_2026][:total])}** |

      ---

      ## 🔮 Income Comparison & Projection

      | Metric | Value |
      |--------|-------|
      | 2025 Full Year Income | $#{format_currency(TAX_2025_INCOME)} |
      | 2026 YTD Income (2 months) | $#{format_currency(@snapshot[:comparison_to_2025][:income_2026_ytd])} |
      | **Projected 2026 Annual** | **$#{format_currency(@snapshot[:comparison_to_2025][:projected_2026_annual])}** |
      | **Growth Rate** | **#{@snapshot[:comparison_to_2025][:growth_rate]}** |

      ---

      ## 🏦 Trust Rollup

      #{generate_trust_rollup_table}

      ---

      ## 📈 Top 10 Holdings (Across All Accounts)

      #{generate_top_holdings_table}

      ---

      ## 📋 Account Summary

      **Total Accounts:** #{@snapshot[:accounts].count}

      #{generate_accounts_summary}

      ---

      ## 🔗 Key Files

      - **JSON Data:** `/Users/ericsmith66/Documents/Taxes/Taxes 2025/data/json/financial_snapshot_2026_02.json`
      - **Summary:** `/Users/ericsmith66/Documents/Taxes/Taxes 2025/data/FINANCIAL_SNAPSHOT_2026_02_SUMMARY.md`

      ---

      *Generated by Financial Snapshot Generator*#{'  '}
      *Data sourced from NextGen Plaid production database*
    MARKDOWN

    File.write(SUMMARY_FILE, md)
  end

  def generate_trust_rollup_table
    rows = @snapshot[:trust_rollup].map do |trust_name, data|
      "| #{trust_name} | $#{format_currency(data[:total_balance])} | $#{format_currency(data[:ytd_income])} | #{data[:account_count]} |"
    end

    header = "| Trust | Total Balance | YTD Income | Accounts |\n|-------|--------------|------------|----------|\n"
    header + rows.join("\n")
  end

  def generate_top_holdings_table
    all_holdings = @snapshot[:accounts].flat_map { |a| a[:top_holdings] }
    top_10 = all_holdings.sort_by { |h| -h[:value] }.take(10)

    return "*No holdings data available*" if top_10.empty?

    header = "| Symbol | Shares | Market Value | Cost Basis | Gain/Loss |\n|--------|--------|--------------|------------|-----------|"
    rows = top_10.map do |h|
      gl = h[:value] - h[:cost_basis]
      "| #{h[:symbol]} | #{h[:shares]} | $#{format_currency(h[:value])} | $#{format_currency(h[:cost_basis])} | $#{format_currency(gl)} |"
    end

    header + "\n" + rows.join("\n")
  end

  def generate_accounts_summary
    @snapshot[:accounts].map do |acct|
      <<~ACCOUNT
        ### #{acct[:account_full_name]} (#{acct[:account_number_last4]})
        - **Trust:** #{acct[:trust_owner]}
        - **Broker:** #{acct[:broker]}
        - **Balance:** $#{format_currency(acct[:current_balance])}
        - **YTD Income:** $#{format_currency(acct[:ytd_2026_income].values.sum)}
        - **Holdings:** #{acct[:top_holdings].count} positions
      ACCOUNT
    end.join("\n")
  end

  def find_trust_owner(last4)
    TRUST_ACCOUNTS.each do |trust_name, masks|
      return trust_name if masks.include?(last4)
    end
    'Unknown'
  end

  def determine_broker(account)
    name = account.name.downcase
    return 'JPM' if name.include?('chase') || name.include?('jpm')
    return 'Schwab' if name.include?('schwab')
    'Unknown'
  end

  def extract_last_4(account_id)
    account_id.to_s.last(4)
  end

  def calculate_gain_percentage
    return 0 if @snapshot[:total_cost_basis].zero?
    ((@snapshot[:total_unrealized_gains] / @snapshot[:total_cost_basis]) * 100).round(2)
  end

  def format_currency(amount)
    amount.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

# Run the generator
begin
  generator = FinancialSnapshotGenerator.new
  generator.generate
rescue StandardError => e
  puts "\n❌ Error generating snapshot: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
