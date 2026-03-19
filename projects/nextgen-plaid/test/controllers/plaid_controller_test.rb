require "test_helper"
require "ostruct"

class PlaidControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "user@example.com", password: "Password!123")
    login_as(@user, scope: :user)
  end

  test "POST /plaid/link_token returns link token" do
    fake_response = OpenStruct.new(link_token: "link-sandbox-123")
    with_stubbed_plaid_client(link_token_create: fake_response) do
      assert_enqueued_jobs 0 do
        post "/plaid/link_token"
        assert_response :success
        body = JSON.parse(@response.body)
        assert_equal "link-sandbox-123", body["link_token"]
      end
    end
  end

  test "POST /plaid/exchange creates PlaidItem and enqueues sync job" do
    fake_exchange = OpenStruct.new(item_id: "item-123", access_token: "access-sandbox-abc")
    with_stubbed_plaid_client(item_public_token_exchange: fake_exchange) do
      assert_enqueued_with(job: SyncHoldingsJob) do
        post "/plaid/exchange", params: { public_token: "public-sandbox-xyz", institution_name: "Test Bank" }
        assert_response :success
      end
    end

    item = PlaidItem.last
    refute_nil item
    assert_equal @user.id, item.user_id
    assert_equal "item-123", item.item_id
    assert_equal "Test Bank", item.institution_name
    assert_equal "good", item.status
    assert item.access_token.present?
  end

  test "POST /plaid/exchange with schwab product_set stores intended_products and only syncs investments and transactions" do
    fake_exchange = OpenStruct.new(item_id: "item-schwab", access_token: "access-sandbox-schwab")
    with_stubbed_plaid_client(item_public_token_exchange: fake_exchange) do
      assert_enqueued_jobs 2 do
        post "/plaid/exchange", params: {
          public_token: "public-sandbox-xyz",
          institution_name: "Charles Schwab",
          product_set: "schwab"
        }
        assert_response :success
      end
    end

    item = PlaidItem.last
    assert_equal "investments,transactions", item.intended_products

    # Verify correct jobs were enqueued
    assert_enqueued_with(job: SyncHoldingsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])

    # Verify liabilities job was NOT enqueued
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "POST /plaid/exchange with amex product_set stores intended_products and only syncs transactions and liabilities" do
    fake_exchange = OpenStruct.new(item_id: "item-amex", access_token: "access-sandbox-amex")
    with_stubbed_plaid_client(item_public_token_exchange: fake_exchange) do
      assert_enqueued_jobs 2 do
        post "/plaid/exchange", params: {
          public_token: "public-sandbox-xyz",
          institution_name: "American Express",
          product_set: "amex"
        }
        assert_response :success
      end
    end

    item = PlaidItem.last
    assert_equal "transactions,liabilities", item.intended_products

    # Verify only transactions + liabilities jobs were enqueued
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncLiabilitiesJob, args: [ item.id ])

    # Verify other jobs were NOT enqueued
    assert_no_enqueued_jobs(only: SyncHoldingsJob)
  end

  test "POST /plaid/exchange with chase product_set stores intended_products and syncs all products" do
    fake_exchange = OpenStruct.new(item_id: "item-chase", access_token: "access-sandbox-chase")
    with_stubbed_plaid_client(item_public_token_exchange: fake_exchange) do
      assert_enqueued_jobs 3 do
        post "/plaid/exchange", params: {
          public_token: "public-sandbox-xyz",
          institution_name: "Chase",
          product_set: "chase"
        }
        assert_response :success
      end
    end

    item = PlaidItem.last
    assert_equal "investments,transactions,liabilities", item.intended_products

    # Verify all jobs were enqueued
    assert_enqueued_with(job: SyncHoldingsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncLiabilitiesJob, args: [ item.id ])
  end
end
