# frozen_string_literal: true

module Transactions
  # Overview stats component using DaisyUI stat cards.
  class SummaryCardComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper

    def initialize(transactions:)
      @transactions = Array(transactions)
    end

    private

    attr_reader :transactions

    def total_count
      transactions.size
    end

    def net_amount
      transactions.sum { |txn| txn.amount.to_f }
    end

    def average_amount
      total_count > 0 ? net_amount / total_count : 0
    end

    def largest_expense
      expenses = transactions.select { |txn| txn.amount.to_f.negative? }
      expenses.min_by(&:amount)&.amount.to_f.abs
    end

    def top_category
      # For simplicity, return a placeholder
      "FOOD_AND_DRINK"
    end
  end
end
