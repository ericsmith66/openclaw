# frozen_string_literal: true

module Transactions
  # Groups transactions by month using DaisyUI collapse/accordion.
  class MonthlyGroupComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper

    def initialize(transactions:)
      @transactions = Array(transactions)
      @groups = group_by_month
    end

    private

    attr_reader :transactions, :groups

    def group_by_month
      groups = Hash.new { |h, k| h[k] = [] }
      transactions.each do |txn|
        date = txn.date
        next unless date.present?

        month_key = date.is_a?(String) ? Date.parse(date).strftime("%Y-%m") : date.strftime("%Y-%m")
        groups[month_key] << txn
      end
      groups.sort_by { |month, _| month }.reverse.to_h
    end

    def month_label(month_key)
      Date.strptime(month_key, "%Y-%m").strftime("%B %Y")
    end

    def monthly_total(month_transactions)
      month_transactions.sum { |txn| txn.amount.to_f }
    end

    def monthly_count(month_transactions)
      month_transactions.size
    end
  end
end
