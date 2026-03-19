# frozen_string_literal: true

module Agents
  module ToolOutputTruncator
    DEFAULT_MAX_OUTPUT_BYTES = 200_000

    # Truncate a string to a byte budget and keep it JSON-safe UTF-8.
    def self.truncate_bytes(str, max_bytes)
      return "" if max_bytes.to_i <= 0
      bytes = str.to_s.b
      if bytes.bytesize <= max_bytes
        safe = bytes.dup.force_encoding("UTF-8")
        return safe.scrub("?")
      end

      truncated = bytes.byteslice(0, max_bytes)
      truncated = truncated.force_encoding("UTF-8")
      truncated = truncated.scrub("?")
      truncated + "\n...[truncated]"
    end

    # Applies truncation to a `{ stdout:, stderr: }` hash.
    # Returns a new hash with metadata fields.
    def self.truncate_result(result, max_bytes: nil)
      max_bytes = Integer(max_bytes || ENV.fetch("AI_TOOL_OUTPUT_MAX_BYTES", DEFAULT_MAX_OUTPUT_BYTES.to_s))
      max_bytes = DEFAULT_MAX_OUTPUT_BYTES if max_bytes <= 0

      stdout_str = result[:stdout].to_s
      stderr_str = result[:stderr].to_s
      stdout_bytes = stdout_str.bytesize
      stderr_bytes = stderr_str.bytesize

      stdout_truncated = stdout_bytes > max_bytes
      stderr_truncated = stderr_bytes > max_bytes

      stdout_str = truncate_bytes(stdout_str, max_bytes) if stdout_truncated
      stderr_str = truncate_bytes(stderr_str, max_bytes) if stderr_truncated

      result.merge(
        stdout: stdout_str,
        stderr: stderr_str,
        stdout_bytes: stdout_bytes,
        stderr_bytes: stderr_bytes,
        stdout_truncated: stdout_truncated,
        stderr_truncated: stderr_truncated
      )
    end
  end
end
