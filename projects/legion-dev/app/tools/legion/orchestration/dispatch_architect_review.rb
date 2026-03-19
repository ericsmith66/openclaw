# frozen_string_literal: true

module Legion
  module OrchestrationTools
    # DispatchArchitectReview orchestration tool
    #
    # Calls ArchitectGate.evaluate to evaluate the decomposition plan
    # before implementation begins. Sits between decomposing and coding phases.
    #
    # FR-7: Integration with Conductor tools:
    #   dispatch_architect_review tool calls ArchitectGate.evaluate
    # AC-9: dispatch_architect_review orchestration tool calls ArchitectGate.evaluate internally
    #
    # @example
    #   result = Legion::OrchestrationTools::DispatchArchitectReview.call(
    #     execution: workflow_execution,
    #     workflow_run: decomposition_run
    #   )
    #   if result.passed?
    #     # Proceed to coding phase
    #   else
    #     # Retry decomposition with feedback
    #   end
    class DispatchArchitectReview
      def self.call(execution:, workflow_run: nil)
        new(execution:, workflow_run:).call
      end

      def initialize(execution:, workflow_run: nil)
        @execution = execution
        @workflow_run = workflow_run
      end

      def call
        gate = ArchitectGate.new(execution: @execution, workflow_run: @workflow_run)
        gate.evaluate
      end
    end
  end
end
