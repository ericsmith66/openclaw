# frozen_string_literal: true

require "json"

# PRD 0030: MCP-like read-only tool
class VcTool < Agents::Tool
  include Agents::ToolGuardrailsMixin

  description "Read-only git operations in the sandbox repo (status/log/diff). Dry-run by default."

  param :action, type: "string", desc: "One of: status, log, diff"
  param :args, type: "object", desc: "Action-specific arguments"

  # End-to-end SDLC runs can legitimately require many VCS queries (status/diff/log)
  # in a single turn. Keep a cap to prevent runaway loops, but make it high enough
  # to cover complex tasks.
  MAX_CALLS_PER_TURN = 60
  MAX_RETRIES = 2
  DEFAULT_TIMEOUT_SECONDS = 30
  DEFAULT_MAX_OUTPUT_BYTES = 200_000

  def perform(tool_context, action:, args: {})
    enforce_tool_guardrails!(tool_context)

    # VcTool is read-only, so it's safe to lazily initialize the sandbox worktree.
    sandbox_repo = tool_context.state[:sandbox_repo]
    if sandbox_repo.blank?
      correlation_id = tool_context.context[:correlation_id] || tool_context.context["correlation_id"]
      raise AiWorkflowService::GuardrailError, "missing correlation_id" if correlation_id.to_s.strip.empty?

      branch = "agent/#{correlation_id}"
      sandbox_repo = AgentSandboxRunner.ensure_worktree!(correlation_id: correlation_id, branch: branch)
      tool_context.state[:sandbox_repo] = sandbox_repo
    end

    action = action.to_s
    argv, cmd = build_command(action, args)

    execute_enabled = ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
    unless execute_enabled
      return JSON.generate({ action: "dry_run", would_run: cmd, cwd: sandbox_repo, stdout: "", stderr: "", status: nil, errors: [] })
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

    max_output_bytes = Integer(ENV.fetch("AI_TOOL_OUTPUT_MAX_BYTES", DEFAULT_MAX_OUTPUT_BYTES.to_s))
    max_output_bytes = DEFAULT_MAX_OUTPUT_BYTES if max_output_bytes <= 0

    stdout_str = res[:stdout].to_s
    stderr_str = res[:stderr].to_s
    stdout_bytes = stdout_str.bytesize
    stderr_bytes = stderr_str.bytesize
    stdout_truncated = stdout_bytes > max_output_bytes
    stderr_truncated = stderr_bytes > max_output_bytes

    stdout_str = truncate_bytes(stdout_str, max_output_bytes) if stdout_truncated
    stderr_str = truncate_bytes(stderr_str, max_output_bytes) if stderr_truncated

    JSON.generate(
      {
        action: "executed",
        cwd: sandbox_repo,
        status: res[:status],
        stdout: stdout_str,
        stderr: stderr_str,
        stdout_bytes: stdout_bytes,
        stderr_bytes: stderr_bytes,
        stdout_truncated: stdout_truncated,
        stderr_truncated: stderr_truncated,
        errors: res[:status].to_i == 0 ? [] : [ stderr_str.presence || "git failed" ]
      }
    )
  end

  private

  def build_command(action, args)
    case action
    when "status"
      argv = %w[git status --porcelain]
      [ argv, argv.join(" ") ]
    when "log"
      limit = Integer(args.fetch("limit", 20))
      limit = 1 if limit < 1
      limit = 100 if limit > 100
      argv = [ "git", "log", "--oneline", "-n", limit.to_s ]
      [ argv, argv.join(" ") ]
    when "diff"
      # requirement: diff against main
      base = args.fetch("base", "main").to_s
      raise AiWorkflowService::GuardrailError, "base must be 'main'" unless base == "main"

      argv = %w[git diff main]
      [ argv, argv.join(" ") ]
    else
      raise AiWorkflowService::GuardrailError, "invalid action: #{action}"
    end
  end

  def truncate_bytes(str, max_bytes)
    return "" if max_bytes.to_i <= 0
    bytes = str.to_s.b
    return str if bytes.bytesize <= max_bytes

    truncated = bytes.byteslice(0, max_bytes)
    # Ensure valid UTF-8 for JSON payloads.
    truncated = truncated.force_encoding("UTF-8")
    truncated = truncated.scrub("?")
    truncated + "\n...[truncated]"
  end
end
