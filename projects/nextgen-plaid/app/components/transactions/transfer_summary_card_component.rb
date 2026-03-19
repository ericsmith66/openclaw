# frozen_string_literal: true

module Transactions
  class TransferSummaryCardComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper

    def initialize(transactions:)
      @transactions = Array(transactions)
    end

    private

    attr_reader :transactions

    def total_count
      transactions.size
    end

    def total_inflows
      transactions.select { |t| t.amount.to_f.positive? }.sum { |t| t.amount.to_f }
    end

    def total_outflows_external
      transactions.select { |t| t.amount.to_f.negative? && external?(t) }.sum { |t| t.amount.to_f.abs }
    end

    def total_internal
      transactions.select { |t| !external?(t) }.sum { |t| t.amount.to_f.abs }
    end

    def external?(txn)
      txn.instance_variable_defined?(:@_external) && txn.instance_variable_get(:@_external)
    end
  end
end
