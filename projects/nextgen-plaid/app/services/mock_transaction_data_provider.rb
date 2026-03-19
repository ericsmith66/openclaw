# frozen_string_literal: true

# Service to load mock transaction data from YAML files in config/mock_transactions/
# Follows *Provider suffix pattern and includes caching for performance.
class MockTransactionDataProvider
  CACHE_TTL = 1.hour

  # Convenience class methods for each transaction type
  def self.cash
    new("cash").call
  end

  def self.investments
    new("investments").call
  end

  def self.credit
    new("credit").call
  end

  def self.transfers
    new("transfers").call
  end

  def self.summary
    new("summary").call
  end

  def initialize(type)
    @type = type
    @file_path = Rails.root.join("config", "mock_transactions", "#{type}.yml")
  end

  def call
    if type == "summary"
      load_summary
    else
      load_yaml
    end
  end

  private

  attr_reader :type, :file_path

  def load_yaml
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      read_and_parse_yaml
    end
  end

  def load_summary
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      read_and_parse_summary
    end
  end

  def read_and_parse_yaml
    return [] unless File.exist?(file_path)

    data = YAML.safe_load_file(file_path, permitted_classes: [ Date, Time, Symbol ])
    transactions = data["transactions"] || []

    # Convert to OpenStruct for attribute access like ActiveRecord
    transactions.map { |txn| OpenStruct.new(txn) }
  rescue StandardError => e
    Rails.logger.error "Failed to load mock transaction data for #{type}: #{e.message}"
    []
  end

  def read_and_parse_summary
    return {} unless File.exist?(file_path)

    data = YAML.safe_load_file(file_path, permitted_classes: [ Date, Time, Symbol ])
    data["summary"] || {}
  rescue StandardError => e
    Rails.logger.error "Failed to load mock summary data for #{type}: #{e.message}"
    {}
  end

  def cache_key
    mtime = File.exist?(file_path) ? File.mtime(file_path).to_i : 0
    "mock_transactions:#{type}:v#{mtime}"
  end
end
