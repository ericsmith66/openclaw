# frozen_string_literal: true

# PRD-AH-013G hardening:
# Our handoff-context work adds a 4th argument (`context_wrapper`) to `agent_handoff` callbacks.
# Some existing callback procs/lambdas have strict arity (e.g., 3 args) and will raise
# `wrong number of arguments` if invoked with 4.
#
# This initializer makes callback dispatch arity-aware and backward compatible:
# - If a callback has a fixed arity N and we have more than N args, we pass only the first N.
# - Variadic callbacks (negative arity) still receive all args.

require "agents/callback_manager"

module Agents
  class CallbackManager
    def emit(event_type, *args)
      callback_list = @callbacks[event_type] || []

      callback_list.each do |callback|
        call_args = args

        begin
          arity = callback.arity
          if arity >= 0 && call_args.length > arity
            call_args = call_args.first(arity)
          end
        rescue StandardError
          # If callback doesn't expose arity reliably, fall back to calling with all args.
          call_args = args
        end

        callback.call(*call_args)
      rescue StandardError => e
        # Log callback errors but don't let them crash execution
        warn "Callback error for #{event_type}: #{e.message}"
      end
    end
  end
end
