# frozen_string_literal: true

module Legion
  module OrchestrationTools
    # DispatchScoring orchestration tool
    #
    # Calls QAGate.evaluate to evaluate the implementation output
    # after coding is complete. Sits between coding and completed phases.
    #
    # FR-7: Integration with Conductor tools:
    #   dispatch_scoring tool calls QAGate.evaluate
    # AC-10: dispatch_scoring orchestration tool calls QAGate.evaluate internally
    #
    # @example
    #   result = Legion::OrchestrationTools::DispatchScoring.call(
    #     execution: workflow_execution,
    #     workflow_run: nil
    #   )
    #   if result.passed?
    #     # Mark execution as completed
    #   else
    #     # Retry coding with feedback
    #   end
    class DispatchScoring
      def self.call(execution:, workflow_run: nil)
        new(execution:, workflow_run:).call
      end

      def initialize(execution:, workflow_run: nil)
        @execution = execution
        @workflow_run = workflow_run
      end

      def call
        gate = QaGate.new(execution: @execution, workflow_run: @workflow_run)
        gate.evaluate
      end
    end
  end
end
