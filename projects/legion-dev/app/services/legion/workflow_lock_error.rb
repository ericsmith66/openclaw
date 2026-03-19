# frozen_string_literal: true

module Legion
  # Raised when a workflow lock cannot be acquired due to contention.
  #
  # This error indicates that another workflow execution is currently holding
  # the advisory lock for a project, preventing concurrent execution.
  class WorkflowLockError < StandardError
    attr_reader :lock_key

    # @param message [String] error message
    # @param lock_key [Integer] the advisory lock key that could not be acquired
    def initialize(message, lock_key)
      super(message)
      @lock_key = lock_key
    end
  end
end
