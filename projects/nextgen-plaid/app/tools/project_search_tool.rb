# frozen_string_literal: true

require "json"

# PRD 0030: MCP-like read-only tool
class ProjectSearchTool < Agents::Tool
  include Agents::ToolGuardrailsMixin

  description "Search the repo for a query (read-only). Restricted to a small allowlist of directories. Dry-run by default."

  param :query, type: "string", desc: "Search query (passed as a literal argument to grep)"
  param :paths, type: "array", desc: "Optional subset of allowed paths: [app, lib, test, config, db]"

  # Allow a minimal set of repo dirs needed for typical Rails changes.
  # `config/` is required for routing updates (e.g., `config/routes.rb`).
  ALLOWED_DIRS = %w[app lib test config db].freeze
  DEFAULT_TIMEOUT_SECONDS = 30

  def perform(tool_context, query:, paths: nil)
    enforce_tool_guardrails!(tool_context)

    sandbox_repo = tool_context.state[:sandbox_repo]
    raise AiWorkflowService::GuardrailError, "sandbox_repo must be set" if sandbox_repo.blank?

    dirs = normalize_dirs(paths)
    argv = [ "grep", "-R", "-n", "--", query.to_s ] + dirs
    cmd = argv.join(" ")

    execute_enabled = ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
    unless execute_enabled
      return JSON.generate({ action: "dry_run", would_run: cmd, cwd: sandbox_repo, results: [], errors: [] })
    end

    timeout_seconds = Integer(ENV.fetch("AI_TOOLS_CMD_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS.to_s))
    res = AgentSandboxRunner.run(
      cmd: cmd,
      argv: argv,
      cwd: sandbox_repo,
      correlation_id: tool_context.context[:correlation_id] || tool_context.context["correlation_id"],
      tool_name: self.class.name,
      timeout_seconds: timeout_seconds
    )

    parsed = parse_grep_output(res[:stdout].to_s)

    JSON.generate(
      {
        action: "executed",
        cwd: sandbox_repo,
        status: res[:status],
        results: parsed,
        errors: res[:status].to_i == 0 ? [] : [ res[:stderr].to_s.presence || "grep failed" ]
      }
    )
  end

  private

  def normalize_dirs(paths)
    requested = Array(paths).map(&:to_s)
    requested = ALLOWED_DIRS if requested.empty?

    unless (requested - ALLOWED_DIRS).empty?
      raise AiWorkflowService::GuardrailError, "paths must be within: #{ALLOWED_DIRS.join(', ')}"
    end

    requested
  end

  def parse_grep_output(stdout)
    # Typical grep format: file:line:content
    stdout.lines.filter_map do |line|
      line = line.chomp
      if (m = line.match(/\A([^:]+):(\d+):(.*)\z/))
        { file: m[1], line: m[2].to_i, text: m[3] }
      end
    end
  end
end
