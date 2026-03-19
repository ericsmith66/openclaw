# frozen_string_literal: true

require "json"
require "time"
require "tempfile"

module AgentDesk
  module Agent
    # Namespace for per-call usage logging implementations.
    #
    # Two concrete implementations are provided:
    # - {NullLogger} — no-op, the default when no persistence is needed
    # - {JsonLogger} — appends JSON records to a file; atomic writes via
    #   temp-file rename to prevent corruption
    #
    # Both implement the same interface:
    # - {#log} — persist a usage record
    # - {#query} — retrieve records within a time range
    #
    # @example Selecting a logger
    #   # Default — no persistence
    #   logger = AgentDesk::Agent::UsageLogger::NullLogger.new
    #
    #   # File-based JSON audit log
    #   logger = AgentDesk::Agent::UsageLogger::JsonLogger.new(path: "/var/log/agent_desk_usage.json")
    module UsageLogger
      # A usage record passed to {#log}.
      #
      # Expected keys (all optional — implementations must be nil-tolerant):
      # - +:timestamp+ [String] ISO 8601 timestamp (defaults to now)
      # - +:model+ [String] model identifier
      # - +:project+ [String] project identifier
      # - +:prompt_tokens+ [Integer]
      # - +:completion_tokens+ [Integer]
      # - +:cache_read_tokens+ [Integer]
      # - +:cache_write_tokens+ [Integer]
      # - +:cost+ [Float] cost in dollars
      # - +:cumulative_cost+ [Float]

      # No-op logger — the default. All methods are safe to call but do nothing.
      #
      # @example
      #   logger = NullLogger.new
      #   logger.log({ model: "gpt-4o", cost: 0.01 })  # => nil
      #   logger.query(from: Time.now - 3600, to: Time.now)  # => []
      class NullLogger
        # @param _record [Hash] ignored
        # @return [nil]
        def log(_record)
          nil
        end

        # @param from [Time, nil] ignored
        # @param to [Time, nil] ignored
        # @return [Array] always empty
        def query(from: nil, to: nil) # rubocop:disable Lint/UnusedMethodArgument
          []
        end
      end

      # File-based JSON logger. Each call to {#log} appends a JSON record to a
      # newline-delimited JSON file (one JSON object per line).
      #
      # Writes are atomic: the entire file is rewritten to a temporary file and
      # renamed over the target to prevent partial writes corrupting the log.
      #
      # Database errors (I/O failures, corrupt JSON) are rescued and logged to
      # +$stderr+ so the runner continues uninterrupted.
      #
      # @example
      #   logger = JsonLogger.new(path: "/tmp/usage.jsonl")
      #   logger.log({ model: "claude-3-5-sonnet", cost: 0.021 })
      #   logger.query(from: Time.now - 86400, to: Time.now)
      class JsonLogger
        # @param path [String] path to the JSON-lines log file (created if absent)
        def initialize(path:)
          @path = path.to_s
        end

        # Appends a usage record to the log file.
        #
        # The record is enriched with a +:timestamp+ field (ISO 8601) when not
        # already present.
        #
        # @param record [Hash] usage data
        # @return [nil]
        def log(record)
          entry = record.merge(timestamp: record[:timestamp] || Time.now.utc.iso8601)
          existing = load_records
          existing << entry
          write_records(existing)
          nil
        rescue StandardError => e
          warn "[AgentDesk::UsageLogger::JsonLogger] log failed: #{e.message}"
          nil
        end

        # Queries log records within an inclusive time range.
        #
        # Both +from+ and +to+ are optional:
        # - When both are nil, all records are returned.
        # - When only +from+ is given, records at or after +from+ are returned.
        # - When only +to+ is given, records at or before +to+ are returned.
        #
        # @param from [Time, nil] inclusive start of range
        # @param to [Time, nil] inclusive end of range
        # @return [Array<Hash>] matching records (symbol-keyed)
        def query(from: nil, to: nil)
          records = load_records
          records.select do |r|
            ts = parse_timestamp(r[:timestamp] || r["timestamp"])
            next true if ts.nil?

            (from.nil? || ts >= from) && (to.nil? || ts <= to)
          end
        rescue StandardError => e
          warn "[AgentDesk::UsageLogger::JsonLogger] query failed: #{e.message}"
          []
        end

        private

        # Loads all records from the log file.
        #
        # @return [Array<Hash>] symbol-keyed records
        def load_records
          return [] unless File.exist?(@path)

          lines = File.readlines(@path, chomp: true).reject(&:empty?)
          lines.map { |line| JSON.parse(line, symbolize_names: true) }
        rescue JSON::ParserError => e
          warn "[AgentDesk::UsageLogger::JsonLogger] corrupt JSON in #{@path}: #{e.message}"
          []
        end

        # Atomically rewrites the log file with +records+.
        #
        # Uses a sibling temp file + rename for atomicity.
        #
        # @param records [Array<Hash>] records to persist
        # @return [void]
        def write_records(records)
          dir  = File.dirname(@path)
          base = File.basename(@path)

          tmp = Tempfile.new([ "agent_desk_usage_", base ], dir)
          begin
            records.each { |r| tmp.puts(JSON.generate(r)) }
            tmp.flush
            tmp.close
            File.rename(tmp.path, @path)
          rescue StandardError
            tmp.close
            tmp.unlink rescue nil # rubocop:disable Style/RescueModifier
            raise
          end
        end

        # Parses an ISO 8601 timestamp string into a +Time+ object.
        #
        # @param ts [String, nil]
        # @return [Time, nil]
        def parse_timestamp(ts)
          return nil if ts.nil?

          Time.parse(ts.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
