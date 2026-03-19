# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "time"

class UsageLoggerTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # NullLogger
  # ---------------------------------------------------------------------------

  def test_null_logger_log_returns_nil
    logger = AgentDesk::Agent::UsageLogger::NullLogger.new
    assert_nil logger.log({ model: "gpt-4o", cost: 0.01 })
  end

  def test_null_logger_query_returns_empty_array
    logger = AgentDesk::Agent::UsageLogger::NullLogger.new
    assert_equal [], logger.query(from: Time.now - 3600, to: Time.now)
  end

  def test_null_logger_query_with_no_args_returns_empty_array
    logger = AgentDesk::Agent::UsageLogger::NullLogger.new
    assert_equal [], logger.query
  end

  def test_null_logger_is_safe_to_call_multiple_times
    logger = AgentDesk::Agent::UsageLogger::NullLogger.new
    5.times { logger.log({ tokens: 100 }) }
    assert_equal [], logger.query
  end

  # ---------------------------------------------------------------------------
  # JsonLogger — basic log and query
  # ---------------------------------------------------------------------------

  def with_json_logger
    Dir.mktmpdir do |dir|
      path = File.join(dir, "usage.jsonl")
      logger = AgentDesk::Agent::UsageLogger::JsonLogger.new(path: path)
      yield logger, path
    end
  end

  def test_json_logger_creates_file_on_first_log
    with_json_logger do |logger, path|
      logger.log({ model: "claude-3-5-sonnet", cost: 0.021 })
      assert File.exist?(path)
    end
  end

  def test_json_logger_persists_record
    with_json_logger do |logger, _path|
      logger.log({ model: "gpt-4o", prompt_tokens: 1000, cost: 0.01 })
      records = logger.query
      assert_equal 1, records.size
      assert_equal "gpt-4o", records.first[:model]
      assert_equal 1000,     records.first[:prompt_tokens]
    end
  end

  def test_json_logger_appends_multiple_records
    with_json_logger do |logger, _path|
      logger.log({ model: "a", cost: 0.01 })
      logger.log({ model: "b", cost: 0.02 })
      logger.log({ model: "c", cost: 0.03 })
      assert_equal 3, logger.query.size
    end
  end

  def test_json_logger_log_returns_nil
    with_json_logger do |logger, _path|
      assert_nil logger.log({ cost: 0.01 })
    end
  end

  def test_json_logger_adds_timestamp_when_missing
    with_json_logger do |logger, _path|
      logger.log({ model: "gpt-4o" })
      record = logger.query.first
      assert record[:timestamp], "expected timestamp to be present"
      # Should parse as valid ISO 8601
      assert_instance_of Time, Time.parse(record[:timestamp])
    end
  end

  def test_json_logger_preserves_existing_timestamp
    ts = "2026-01-01T00:00:00Z"
    with_json_logger do |logger, _path|
      logger.log({ model: "gpt-4o", timestamp: ts })
      record = logger.query.first
      assert_equal ts, record[:timestamp]
    end
  end

  # ---------------------------------------------------------------------------
  # JsonLogger — query with time filters
  # ---------------------------------------------------------------------------

  def test_json_logger_query_filters_by_from
    with_json_logger do |logger, _path|
      logger.log({ model: "old", timestamp: "2026-01-01T00:00:00Z" })
      logger.log({ model: "new", timestamp: "2026-06-01T00:00:00Z" })

      from = Time.parse("2026-03-01T00:00:00Z")
      results = logger.query(from: from)
      assert_equal 1, results.size
      assert_equal "new", results.first[:model]
    end
  end

  def test_json_logger_query_filters_by_to
    with_json_logger do |logger, _path|
      logger.log({ model: "old", timestamp: "2026-01-01T00:00:00Z" })
      logger.log({ model: "new", timestamp: "2026-06-01T00:00:00Z" })

      to = Time.parse("2026-03-01T00:00:00Z")
      results = logger.query(to: to)
      assert_equal 1, results.size
      assert_equal "old", results.first[:model]
    end
  end

  def test_json_logger_query_filters_by_range
    with_json_logger do |logger, _path|
      logger.log({ model: "a", timestamp: "2026-01-01T00:00:00Z" })
      logger.log({ model: "b", timestamp: "2026-04-01T00:00:00Z" })
      logger.log({ model: "c", timestamp: "2026-09-01T00:00:00Z" })

      from = Time.parse("2026-02-01T00:00:00Z")
      to   = Time.parse("2026-07-01T00:00:00Z")
      results = logger.query(from: from, to: to)
      assert_equal 1, results.size
      assert_equal "b", results.first[:model]
    end
  end

  def test_json_logger_query_no_args_returns_all
    with_json_logger do |logger, _path|
      3.times { |i| logger.log({ model: "m#{i}" }) }
      assert_equal 3, logger.query.size
    end
  end

  # ---------------------------------------------------------------------------
  # JsonLogger — resilience (missing file, graceful errors)
  # ---------------------------------------------------------------------------

  def test_json_logger_query_on_missing_file_returns_empty_array
    Dir.mktmpdir do |dir|
      path = File.join(dir, "nonexistent.jsonl")
      logger = AgentDesk::Agent::UsageLogger::JsonLogger.new(path: path)
      assert_equal [], logger.query
    end
  end

  def test_json_logger_log_does_not_raise_on_io_error
    Dir.mktmpdir do |dir|
      path = File.join(dir, "usage.jsonl")
      logger = AgentDesk::Agent::UsageLogger::JsonLogger.new(path: path)
      # Make directory read-only to cause I/O failure
      FileUtils.chmod(0o555, dir)
      raised = nil
      begin
        logger.log({ cost: 0.01 })
      rescue StandardError => e
        raised = e
      end
      assert_nil raised, "expected no exception but got: #{raised&.inspect}"
    ensure
      FileUtils.chmod(0o755, dir)
    end
  end
end
