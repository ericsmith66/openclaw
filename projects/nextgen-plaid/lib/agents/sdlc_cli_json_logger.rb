# frozen_string_literal: true

require "json"
require "fileutils"

module Agents
  class SdlcCliJsonLogger
    def initialize(path:, run_id:, argv:, debug: false)
      @path = path
      @run_id = run_id
      @argv = argv
      @debug = debug
      FileUtils.mkdir_p(File.dirname(path))
    end

    def info(event:, stage:, artifact_id: nil, ai_workflow_run_id: nil, duration_ms: nil, extra: {})
      write(level: "info", event: event, stage: stage, artifact_id: artifact_id, ai_workflow_run_id: ai_workflow_run_id,
            duration_ms: duration_ms, extra: extra)
    end

    def error(event:, stage:, artifact_id: nil, ai_workflow_run_id: nil, duration_ms: nil, exception: nil, extra: {})
      err = if exception
        {
          "class" => exception.class.to_s,
          "message" => exception.message
        }.tap do |h|
          h["backtrace"] = exception.backtrace if @debug && exception.backtrace
        end
      end

      write(level: "error", event: event, stage: stage, artifact_id: artifact_id, ai_workflow_run_id: ai_workflow_run_id,
            duration_ms: duration_ms, error: err, extra: extra)
    end

    private

    def write(level:, event:, stage:, artifact_id:, ai_workflow_run_id:, duration_ms:, error: nil, extra: {})
      record = {
        "timestamp" => Time.current.iso8601,
        "level" => level,
        "event" => event,
        "run_id" => @run_id,
        "argv" => @argv,
        "stage" => stage,
        "artifact_id" => artifact_id,
        "ai_workflow_run_id" => ai_workflow_run_id,
        "duration_ms" => duration_ms
      }.compact

      record["error"] = error if error
      record.merge!(extra) if extra.present?

      File.open(@path, "a") { |f| f.puts(JSON.generate(record)) }
    end
  end
end
