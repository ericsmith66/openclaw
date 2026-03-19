# frozen_string_literal: true

class NetWorth::TransactionsSummaryComponentPreview < ViewComponent::Preview
  def default
    render(NetWorth::TransactionsSummaryComponent.new(data: {
      "transactions_summary" => {
        "month" => {
          "income" => 12_345.67,
          "expenses" => 8_765.43,
          "net" => 3_580.24
        }
      }
    }))
  end

  def no_data
    render(NetWorth::TransactionsSummaryComponent.new(data: { "transactions_summary" => {} }))
  end

  def large_values
    render(NetWorth::TransactionsSummaryComponent.new(data: {
      "transactions_summary" => {
        "month" => {
          "income" => 9_999_999,
          "expenses" => 1_234_567,
          "net" => 8_765_432
        }
      }
    }))
  end

  def negative_net
    render(NetWorth::TransactionsSummaryComponent.new(data: {
      "transactions_summary" => {
        "month" => {
          "income" => 2_000,
          "expenses" => 5_000,
          "net" => -3_000
        }
      }
    }))
  end
end
