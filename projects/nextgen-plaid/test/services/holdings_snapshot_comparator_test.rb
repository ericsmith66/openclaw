require "test_helper"
require "ostruct"

class HoldingsSnapshotComparatorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "compare@example.com", password: "password")
  end

  test "snapshot vs snapshot computes overall and per-security deltas" do
    start_snapshot = HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "Start",
      snapshot_data: {
        holdings: [
          { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 1, market_value: 100 },
          { security_id: "sec_ge", ticker_symbol: "GE", name: "General Electric", quantity: 2, market_value: 50 }
        ],
        totals: { portfolio_value: 150 }
      }
    )

    end_snapshot = HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "End",
      snapshot_data: {
        holdings: [
          { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 2, market_value: 150 },
          { security_id: "sec_tsla", ticker_symbol: "TSLA", name: "Tesla", quantity: 1, market_value: 200 }
        ],
        totals: { portfolio_value: 350 }
      }
    )

    provider_payload_for = lambda do |snapshot_id|
      case snapshot_id.to_s
      when start_snapshot.id.to_s
        OpenStruct.new(
          holdings: [
            { parent: { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 1, market_value: 100 }, children: [] },
            { parent: { security_id: "sec_ge", ticker_symbol: "GE", name: "General Electric", quantity: 2, market_value: 50 }, children: [] }
          ]
        )
      when end_snapshot.id.to_s
        OpenStruct.new(
          holdings: [
            { parent: { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 2, market_value: 150 }, children: [] },
            { parent: { security_id: "sec_tsla", ticker_symbol: "TSLA", name: "Tesla", quantity: 1, market_value: 200 }, children: [] }
          ]
        )
      else
        OpenStruct.new(holdings: [])
      end
    end

    provider_instance = Struct.new(:payload) do
      def call
        payload
      end
    end

    HoldingsGridDataProvider.stub(:new, lambda { |user, params|
      provider_instance.new(provider_payload_for.call(params[:snapshot_id]))
    }) do
      result = HoldingsSnapshotComparator.new(
        start_snapshot_id: start_snapshot.id,
        end_snapshot_id: end_snapshot.id,
        user_id: @user.id,
        cache: false
      ).call

      assert_nil result[:error]
      assert_equal 150.0, result.dig(:overall, :start_value)
      assert_equal 350.0, result.dig(:overall, :end_value)
      assert_equal 200.0, result.dig(:overall, :delta_value)
      assert_equal 133.33, result.dig(:overall, :period_return_pct)

      securities = result[:securities]

      aapl = securities["sec:sec_aapl"]
      assert_equal :changed, aapl[:status]
      assert_equal 1.0, aapl[:delta_qty]
      assert_equal 50.0, aapl[:delta_value]
      assert_equal 50.0, aapl[:return_pct]

      tsla = securities["sec:sec_tsla"]
      assert_equal :added, tsla[:status]
      assert_equal 1.0, tsla[:delta_qty]
      assert_equal 200.0, tsla[:delta_value]
      assert_nil tsla[:return_pct]

      ge = securities["sec:sec_ge"]
      assert_equal :removed, ge[:status]
      assert_equal(-2.0, ge[:delta_qty])
      assert_equal(-50.0, ge[:delta_value])
      assert_nil ge[:return_pct]
    end
  end

  test "zero start value returns nil return_pct" do
    start_snapshot = HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "Start",
      snapshot_data: {
        holdings: [
          { security_id: "sec_zero", ticker_symbol: "ZERO", name: "Zero", quantity: 0, market_value: 0 }
        ]
      }
    )

    end_snapshot = HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "End",
      snapshot_data: {
        holdings: [
          { security_id: "sec_zero", ticker_symbol: "ZERO", name: "Zero", quantity: 1, market_value: 10 }
        ]
      }
    )

    provider_instance = Struct.new(:payload) do
      def call
        payload
      end
    end

    HoldingsGridDataProvider.stub(:new, lambda { |_user, params|
      payload = if params[:snapshot_id].to_s == start_snapshot.id.to_s
        OpenStruct.new(holdings: [ { parent: { security_id: "sec_zero", ticker_symbol: "ZERO", name: "Zero", quantity: 0, market_value: 0 }, children: [] } ])
      else
        OpenStruct.new(holdings: [ { parent: { security_id: "sec_zero", ticker_symbol: "ZERO", name: "Zero", quantity: 1, market_value: 10 }, children: [] } ])
      end
      provider_instance.new(payload)
    }) do
      result = HoldingsSnapshotComparator.new(
        start_snapshot_id: start_snapshot.id,
        end_snapshot_id: end_snapshot.id,
        user_id: @user.id,
        cache: false
      ).call

      entry = result.dig(:securities, "sec:sec_zero")
      assert_equal :changed, entry[:status]
      assert_nil entry[:return_pct]
      assert_nil result.dig(:overall, :period_return_pct)
    end
  end

  test "snapshot vs current uses provider output" do
    start_snapshot = HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "Start",
      snapshot_data: {
        holdings: [
          { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 1, market_value: 100 }
        ]
      }
    )

    start_payload = OpenStruct.new(
      holdings: [
        {
          parent: { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 1, market_value: 100 },
          children: []
        }
      ]
    )

    live_payload = OpenStruct.new(
      holdings: [
        {
          parent: { security_id: "sec_aapl", ticker_symbol: "AAPL", name: "Apple", quantity: 2, market_value: 150 },
          children: []
        }
      ]
    )

    provider_instance = Struct.new(:payload) do
      def call
        payload
      end
    end

    HoldingsGridDataProvider.stub(:new, lambda { |_user, params|
      payload = if params[:snapshot_id].to_s == start_snapshot.id.to_s
        start_payload
      else
        live_payload
      end
      provider_instance.new(payload)
    }) do
      result = HoldingsSnapshotComparator.new(
        start_snapshot_id: start_snapshot.id,
        end_snapshot_id: :current,
        user_id: @user.id,
        cache: false
      ).call

      assert_nil result[:error], result[:error].inspect
      assert_equal 100.0, result.dig(:overall, :start_value)
      assert_equal 150.0, result.dig(:overall, :end_value)
      assert_equal 50.0, result.dig(:overall, :delta_value)
      assert_equal 50.0, result.dig(:overall, :period_return_pct)
    end
  end
end
