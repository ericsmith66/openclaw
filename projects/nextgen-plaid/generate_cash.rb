#!/usr/bin/env ruby
require 'yaml'
require 'date'

transactions = []
start_date = Date.today - 180
100.times do |i|
  date = start_date + rand(180)
  amount = rand(-500..-1) * 10 + rand(-99..99) / 100.0
  merchants = [ 'Starbucks', 'Whole Foods', 'Amazon', 'Target', 'Walmart', 'Netflix', 'Spotify', 'Uber', 'Lyft', 'Shell', 'Exxon', 'CVS', 'Walgreens', 'Costco', "Trader Joe's", 'Apple', 'Google', 'Microsoft', 'AT&T', 'Verizon' ]
  merchant = merchants.sample
  name = "#{merchant} Purchase"
  pending = rand < 0.1
  transactions << {
    'date' => date.strftime('%Y-%m-%d'),
    'name' => name,
    'amount' => amount.round(2),
    'merchant_name' => merchant,
    'personal_finance_category_label' => [ 'FOOD_AND_DRINK', 'SHOPPING', 'TRANSPORTATION', 'ENTERTAINMENT', 'UTILITIES' ].sample,
    'pending' => pending,
    'payment_channel' => [ 'in store', 'online', 'mobile' ].sample,
    'account_name' => [ 'Chase Checking', 'Wells Fargo Savings', 'Bank of America Checking' ].sample,
    'account_type' => 'depository',
    'transaction_id' => "mock_txn_#{i+1000}",
    'source' => 'manual',
    'subtype' => nil,
    'category' => nil,
    'type' => 'RegularTransaction'
  }
end

data = { 'transactions' => transactions }
File.write('config/mock_transactions/cash.yml', data.to_yaml)
puts "Generated #{transactions.size} transactions."
