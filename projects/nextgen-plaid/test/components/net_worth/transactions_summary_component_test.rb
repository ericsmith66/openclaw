# frozen_string_literal: true

require "test_helper"

class NetWorth::TransactionsSummaryComponentTest < ViewComponent::TestCase
  def test_renders_income_expenses_and_net
    data = {
      "transactions_summary" => {
        "month" => {
          "income" => 10_000,
          "expenses" => 2_000,
          "net" => 8_000
        }
      }
    }

    rendered = render_inline(NetWorth::TransactionsSummaryComponent.new(data: data))

    assert_includes rendered.css(".transactions-income").text, "$10,000"
    assert_includes rendered.css(".transactions-expenses").text, "-$2,000"
    assert_includes rendered.css(".transactions-net").text, "+$8,000"
  end

  def test_empty_state_when_month_missing
    rendered = render_inline(NetWorth::TransactionsSummaryComponent.new(data: {}))

    assert_includes rendered.text, "No recent transactions—sync accounts"
  end
end
