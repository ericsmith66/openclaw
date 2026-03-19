# frozen_string_literal: true

module NetWorth
  class EmptyStateComponent < BaseCardComponent
    def initialize(context:, message_override: nil, cta_path: nil)
      @context = context&.to_sym
      @message_override = message_override
      @cta_path = cta_path
    end

    private

    attr_reader :context, :message_override, :cta_path

    def message
      override = presence(message_override)
      return override if override

      case context
      when :no_snapshot
        "Generating your first snapshot. Check back soon!"
      when :no_items
        "Connect your financial accounts to get started."
      when :sync_pending
        "Syncing your accounts..."
      when :data_missing
        "No data available yet."
      else
        "No data available."
      end
    end
  end
end
