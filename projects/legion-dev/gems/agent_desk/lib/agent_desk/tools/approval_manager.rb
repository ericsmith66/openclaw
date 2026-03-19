# frozen_string_literal: true

require "set"

module AgentDesk
  module Tools
    # Manages tool approval policies and gates tool execution.
    #
    # Each tool has an approval state (ALWAYS / ASK / NEVER) from the agent
    # profile. The ApprovalManager checks this state and optionally prompts
    # the user via a callback when the state is ASK.
    #
    # It also tracks "always for this run" decisions — when a user answers 'r'
    # (remember for run), subsequent calls for that tool skip the ask.
    #
    # Thread-safety note: ApprovalManager is not thread-safe by design. The
    # Runner loop is single-threaded, so all approval checks are serialized.
    class ApprovalManager
      # @param tool_approvals [Hash{String => String}] map of full_name → approval state constant
      # @param auto_approve [Boolean] when true, all tools are auto-approved (bypasses all checks)
      # @param ask_user_block [Proc, nil] block called with (text, subject) when state is ASK;
      #   expected to return 'y', 'a', 'r', or another string (rejection reason)
      def initialize(tool_approvals:, auto_approve: false, &ask_user_block)
        @tool_approvals = tool_approvals
        @auto_approve = auto_approve
        @ask_user_block = ask_user_block
        @always_for_run = Set.new
      end

      # Checks whether a tool is approved to execute.
      #
      # Logic:
      # 1. If auto_approve is set → approved
      # 2. If tool was previously remembered for this run → approved
      # 3. If tool's state is ALWAYS (or unknown) → approved
      # 4. If tool's state is NEVER → rejected with "Tool is disabled"
      # 5. If tool's state is ASK and no ask block → rejected with nil reason
      # 6. If tool's state is ASK and ask block present:
      #    - 'y' or 'a' → approved
      #    - 'r' → remember for run, approved
      #    - anything else → rejected, answer is the reason
      #
      # @param tool_full_name [String] the fully-qualified tool name (e.g., "power---bash")
      # @param text [String] human-readable description of what the tool is about to do
      # @param subject [String, nil] optional subject/title for the approval prompt
      # @return [Array(Boolean, String, nil)] `[approved, reason]` where reason is nil on approval
      def check_approval(tool_full_name, text:, subject: nil)
        return [ true, nil ] if @auto_approve
        return [ true, nil ] if @always_for_run.include?(tool_full_name)

        state = @tool_approvals.fetch(tool_full_name, ToolApprovalState::ALWAYS)

        return [ true, nil ]                    if state == ToolApprovalState::ALWAYS
        return [ false, "Tool is disabled" ]    if state == ToolApprovalState::NEVER

        # state == ASK
        unless @ask_user_block
          return [ false, nil ]
        end

        answer = @ask_user_block.call(text, subject)

        case answer
        when "y", "a"
          [ true, nil ]
        when "r"
          @always_for_run.add(tool_full_name)
          [ true, nil ]
        else
          [ false, answer ]
        end
      end
    end
  end
end
