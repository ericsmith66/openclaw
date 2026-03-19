# frozen_string_literal: true

module Legion
  class StatusService
    ExecutionNotFoundError = Class.new(StandardError)

    def self.call(execution_id:, project_path:)
      new(execution_id:, project_path:).call
    end

    def initialize(execution_id:, project_path:)
      @execution_id = execution_id
      @project_path = project_path
    end

    def call
      execution = find_execution
      build_result(execution)
    rescue ExecutionNotFoundError => e
      Result.new(success: false, execution: nil, error: e.message)
    rescue StandardError => e
      Result.new(success: false, execution: nil, error: e.message)
    end

    private

    def find_execution
      execution = WorkflowExecution.find_by(id: @execution_id)
      raise ExecutionNotFoundError, "WorkflowExecution ##{@execution_id} not found" unless execution
      execution
    end

    def build_result(execution)
      Result.new(
        success: true,
        execution: execution,
        error: nil
      )
    end

    Result = Struct.new(:success, :execution, :error, keyword_init: true)
  end
end
