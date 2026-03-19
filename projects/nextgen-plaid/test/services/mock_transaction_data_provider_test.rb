require "test_helper"

class MockTransactionDataProviderTest < ActiveSupport::TestCase
  setup do
    @old_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
    @cash_file = Rails.root.join("config", "mock_transactions", "cash.yml")
    @summary_file = Rails.root.join("config", "mock_transactions", "summary.yml")
    # Backup existing files if any
    @cash_backup = File.exist?(@cash_file) ? File.read(@cash_file) : nil
    @summary_backup = File.exist?(@summary_file) ? File.read(@summary_file) : nil
  end

  teardown do
    Rails.cache = @old_cache_store
    # Restore original files
    if @cash_backup
      File.write(@cash_file, @cash_backup)
    else
      File.delete(@cash_file) if File.exist?(@cash_file)
    end
    if @summary_backup
      File.write(@summary_file, @summary_backup)
    else
      File.delete(@summary_file) if File.exist?(@summary_file)
    end
  end

  test "loads cash transactions from YAML" do
    yaml_data = {
      "transactions" => [
        {
          "date" => "2026-01-15",
          "name" => "Test Purchase",
          "amount" => -50.0,
          "merchant_name" => "Test Merchant",
          "personal_finance_category_label" => "SHOPPING",
          "pending" => false,
          "payment_channel" => "online",
          "account_name" => "Test Account",
          "account_type" => "depository",
          "transaction_id" => "test_txn_001",
          "source" => "manual",
          "type" => "RegularTransaction"
        }
      ]
    }
    File.write(@cash_file, yaml_data.to_yaml)

    result = MockTransactionDataProvider.cash
    assert_equal 1, result.size
    transaction = result.first
    assert_equal "2026-01-15", transaction.date
    assert_equal "Test Purchase", transaction.name
    assert_equal -50.0, transaction.amount
    assert_equal "Test Merchant", transaction.merchant_name
    assert_equal "SHOPPING", transaction.personal_finance_category_label
    assert_equal false, transaction.pending
    assert_equal "online", transaction.payment_channel
    assert_equal "Test Account", transaction.account_name
    assert_equal "depository", transaction.account_type
    assert_equal "test_txn_001", transaction.transaction_id
    assert_equal "manual", transaction.source
    assert_equal "RegularTransaction", transaction.type
  end

  test "returns empty array when YAML file missing" do
    File.delete(@cash_file) if File.exist?(@cash_file)
    result = MockTransactionDataProvider.cash
    assert_equal [], result
  end

  test "returns empty array when YAML file has no transactions key" do
    File.write(@cash_file, { "other" => "data" }.to_yaml)
    result = MockTransactionDataProvider.cash
    assert_equal [], result
  end

  test "caches loaded data" do
    yaml_data = { "transactions" => [ { "name" => "Cached", "amount" => -10.0 } ] }
    File.write(@cash_file, yaml_data.to_yaml)
    mtime = File.mtime(@cash_file)

    # Use a fixed cache key to test caching independently of mtime if needed,
    # but here we test the real cache key logic.
    provider = MockTransactionDataProvider.new("cash")
    cache_key = provider.send(:cache_key)

    result1 = provider.call
    assert_equal 1, result1.size

    # Manually populate cache with old data for this key
    Rails.cache.write(cache_key, result1)

    # Modify file - cache should prevent reload if we use the same cache key
    File.write(@cash_file, { "transactions" => [] }.to_yaml)
    # Reset mtime to ensure same cache key
    File.utime(File.atime(@cash_file), mtime, @cash_file)

    assert_equal cache_key, provider.send(:cache_key)
    result2 = provider.call
    assert_equal 1, result2.size # Still cached

    # Clear cache and verify new data
    Rails.cache.clear
    result3 = provider.call
    assert_equal 0, result3.size
  end

  test "cache key includes file modification time" do
    File.write(@cash_file, { "transactions" => [] }.to_yaml)
    mtime = File.mtime(@cash_file).to_i
    provider = MockTransactionDataProvider.new("cash")
    assert_includes provider.send(:cache_key), ":v#{mtime}"
  end

  test "loads summary data from YAML" do
    yaml_data = {
      "summary" => {
        "total_transactions" => 100,
        "total_amount" => -5000.0,
        "categories" => { "FOOD_AND_DRINK" => 30 }
      }
    }
    File.write(@summary_file, yaml_data.to_yaml)

    result = MockTransactionDataProvider.summary
    assert_equal 100, result["total_transactions"]
    assert_equal -5000.0, result["total_amount"]
    assert_equal({ "FOOD_AND_DRINK" => 30 }, result["categories"])
  end

  test "summary returns empty hash when file missing" do
    File.delete(@summary_file) if File.exist?(@summary_file)
    result = MockTransactionDataProvider.summary
    assert_equal({}, result)
  end

  test "summary returns empty hash when no summary key" do
    File.write(@summary_file, { "other" => "data" }.to_yaml)
    result = MockTransactionDataProvider.summary
    assert_equal({}, result)
  end
end
