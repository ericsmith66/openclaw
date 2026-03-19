# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module AiWorkflow
  class ArtifactWriter
    def initialize(correlation_id, cwa_cli_log_path: nil, cwa_summary_path: nil)
      @correlation_id = correlation_id.to_s
      @cwa_cli_log_path = cwa_cli_log_path.to_s.strip.presence
      @cwa_summary_path = cwa_summary_path.to_s.strip.presence
      @cwa_task_log_service = Ai::CwaTaskLogService.new(correlation_id: @correlation_id, artifact_writer: self)
      @events = []
    end

    def attach_callbacks!(runner)
      runner.on_run_start(&method(:on_run_start))
      runner.on_agent_thinking(&method(:on_agent_thinking))
      runner.on_agent_handoff(&method(:on_agent_handoff))
      runner.on_agent_complete(&method(:on_agent_complete))
      runner.on_run_complete(&method(:on_run_complete))
      runner.on_tool_start(&method(:on_tool_start))
      runner.on_tool_complete(&method(:on_tool_complete))
      runner
    end

    def record_event(payload)
      write_event(payload)
    end

    def write_run_json(result)
      write_json("run.json", {
        correlation_id: @correlation_id,
        output: result.output,
        error: result.error&.message,
        error_class: result.error&.class&.name,
        error_backtrace: result.error&.backtrace,
        context: result.context,
        usage: result.usage,
        cwa_log: @cwa_task_log_service&.snapshot,
        cwa_log_markdown: @cwa_task_log_service&.markdown
      })

      write_cwa_summary!
    end

    def write_run_payload(payload)
      enriched = payload.merge(
        cwa_log: @cwa_task_log_service&.snapshot,
        cwa_log_markdown: @cwa_task_log_service&.markdown
      )
      write_json("run.json", enriched)
    end

    def write_error(error)
      write_event(
        type: "error",
        message: error.message,
        error_class: error.class.name,
        error_backtrace: error.backtrace
      )
      write_json("run.json", {
        correlation_id: @correlation_id,
        error: error.message,
        error_class: error.class.name,
        error_backtrace: error.backtrace
      })
    end

    private

    def base_dir
      Rails.root.join("agent_logs", "ai_workflow", @correlation_id)
    end

    def ensure_dir!
      FileUtils.mkdir_p(base_dir)
    end

    def events_path
      base_dir.join("events.ndjson")
    end

    def write_json(filename, payload)
      ensure_dir!
      File.write(base_dir.join(filename), JSON.pretty_generate(payload) + "\n")
    end

    def write_event(payload)
      ensure_dir!
      enriched = payload.merge(
        correlation_id: @correlation_id,
        ts: Time.now.utc.iso8601
      )
      @events << enriched
      File.open(events_path, "a") { |f| f.puts(enriched.to_json) }

      broadcast_event(enriched)
    end

    def broadcast_event(event)
      return if Ai::TestMode.enabled?

      # Broadcast to Admin Workflow Monitor
      if defined?(Turbo::StreamsChannel)
        Turbo::StreamsChannel.broadcast_prepend_to(
          "ai_workflow_#{@correlation_id}",
          target: "ai_workflow_events",
          partial: "admin/ai_workflow/event",
          locals: { event: event }
        )
      end

      # Broadcast to Agent Hub Workflow Monitor (Epic 8)
      if event[:type] == "agent_handoff"
        ActionCable.server.broadcast("agent_hub_channel_workflow_monitor", {
          type: "token",
          message_id: "handoff-#{Time.now.to_i}",
          token: "🔄 [HANDOFF] #{event[:from]} -> #{event[:to]} (Reason: #{event[:reason]})"
        })
      end
    rescue StandardError => e
      raise if Rails.env.test?
      Rails.logger&.warn("ai_workflow broadcast failed: #{e.class}: #{e.message}")
    end

    def on_run_start(agent_name, input, _context_wrapper)
      write_event(type: "run_start", agent: agent_name, input: input)
      @cwa_task_log_service.on_run_start(agent_name, input, _context_wrapper)
    end

    def on_agent_thinking(agent_name, input)
      write_event(type: "agent_thinking", agent: agent_name, input: input)
    end

    def on_agent_handoff(from_agent, to_agent, reason)
      write_event(type: "agent_handoff", from: from_agent, to: to_agent, reason: reason)
      @cwa_task_log_service.on_agent_handoff(from_agent, to_agent, reason)
    end

    def on_agent_complete(agent_name, result, error, _context_wrapper)
      write_event(
        type: "agent_complete",
        agent: agent_name,
        output: result&.output,
        error: error&.message,
        error_class: error&.class&.name,
        error_backtrace: error&.backtrace
      )
      @cwa_task_log_service.on_agent_complete(agent_name, result, error, _context_wrapper)
    end

    def on_run_complete(agent_name, result, _context_wrapper)
      write_event(type: "run_complete", agent: agent_name, output: result&.output)
      @cwa_task_log_service.on_run_complete(agent_name, result, _context_wrapper)
    end

    def on_tool_start(tool_name, args)
      write_event(type: "tool_start", tool: tool_name, args: args)
      @cwa_task_log_service.on_tool_start(tool_name, args)

      append_cwa_cli_log(type: "tool_start", tool: tool_name, args: args)
    end

    def on_tool_complete(tool_name, result)
      write_event(type: "tool_complete", tool: tool_name, result: result)
      @cwa_task_log_service.on_tool_complete(tool_name, result)

      append_cwa_cli_log(type: "tool_complete", tool: tool_name, result: result)
    end

    def write_cwa_summary!
      return if @cwa_summary_path.blank?

      FileUtils.mkdir_p(File.dirname(@cwa_summary_path))
      File.write(@cwa_summary_path, @cwa_task_log_service&.markdown.to_s)
    rescue StandardError
      # ignore
    end

    def append_cwa_cli_log(payload)
      return if @cwa_cli_log_path.blank?

      FileUtils.mkdir_p(File.dirname(@cwa_cli_log_path))
      enriched = payload.merge(ts: Time.now.utc.iso8601, correlation_id: @correlation_id)
      File.open(@cwa_cli_log_path, "a") { |f| f.puts(enriched.to_json) }
    rescue StandardError
      # ignore
    end
  end
end
