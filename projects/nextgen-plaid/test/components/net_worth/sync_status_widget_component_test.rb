# frozen_string_literal: true

require "test_helper"

class NetWorthSyncStatusWidgetComponentTest < ViewComponent::TestCase
  test "renders up to date state by default" do
    user = users(:one)
    snapshot = FinancialSnapshot.new(created_at: 2.minutes.ago)

    render_inline(NetWorth::SyncStatusWidgetComponent.new(user: user, snapshot: snapshot, status: :complete))

    assert_selector "button", text: "Refresh"
    assert_selector "[aria-label='Up to date']"
    assert_text "Last sync"

    signed = Turbo::StreamsChannel.signed_stream_name("net_worth:sync_status:#{user.id}")
    assert_includes rendered_content, signed
  end

  test "renders pending state with disabled refresh" do
    user = users(:one)

    render_inline(NetWorth::SyncStatusWidgetComponent.new(user: user, snapshot: nil, status: :pending))

    assert_selector "button[disabled]", text: "Refresh"
    assert_selector "[aria-label='Syncing']"
    assert_text "usually takes 30"
  end

  test "renders error state with reason" do
    user = users(:one)

    render_inline(NetWorth::SyncStatusWidgetComponent.new(user: user, snapshot: nil, status: :error, error_reason: "Boom"))

    assert_selector "[aria-label='Sync error']"
    assert_text "Boom"
  end

  test "renders rate limited state with countdown" do
    user = users(:one)

    render_inline(NetWorth::SyncStatusWidgetComponent.new(user: user, snapshot: nil, status: :rate_limited, retry_after: 45))

    assert_selector "[aria-label='Refresh rate limited']"
    assert_selector "[data-controller='countdown']"
    assert_selector "[data-countdown-seconds-value='45']"
    assert_text "try again in"
  end
end
