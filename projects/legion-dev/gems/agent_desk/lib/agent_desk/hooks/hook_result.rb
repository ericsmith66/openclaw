# frozen_string_literal: true

module AgentDesk
  module Hooks
    # Lightweight data class for hook results.
    #
    # @!attribute [r] blocked
    #   @return [Boolean] whether the event is blocked (default: false)
    # @!attribute [r] event
    #   @return [Hash] the (possibly modified) event data (default: {})
    # @!attribute [r] result
    #   @return [Object, nil] an optional result value (default: nil)
    HookResult = Data.define(:blocked, :event, :result) do
      # @param blocked [Boolean] whether the event is blocked
      # @param event [Hash] the (possibly modified) event data
      # @param result [Object, nil] an optional result value
      def initialize(blocked: false, event: {}, result: nil)
        super
      end
    end
  end
end
