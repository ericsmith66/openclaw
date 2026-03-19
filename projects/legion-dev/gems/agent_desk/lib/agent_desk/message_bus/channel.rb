# frozen_string_literal: true

module AgentDesk
  module MessageBus
    # Dot-delimited channel name with wildcard pattern matching.
    #
    # Channels use a dot-delimited hierarchy (e.g., +"agent.qa.response.chunk"+).
    # Patterns can use a trailing +.*+ to match any sub-path beneath a prefix,
    # or a bare +"*"+ to match every channel.
    #
    # @example
    #   Channel.match?("agent.*",               "agent.qa.response.chunk") #=> true
    #   Channel.match?("agent.qa.*",             "agent.qa.response.chunk") #=> true
    #   Channel.match?("agent.qa.response.chunk","agent.qa.response.chunk") #=> true
    #   Channel.match?("agent.qa.*",             "agent.other.thing")       #=> false
    #   Channel.match?("*",                      "anything.at.all")         #=> true
    module Channel
      # Returns +true+ if +channel+ matches +pattern+.
      #
      # Matching rules:
      # - Bare +"*"+ matches every channel.
      # - Exact equality matches.
      # - Pattern ending in +.*+ matches any channel whose string representation
      #   starts with the pattern prefix followed by a dot
      #   (e.g., +"agent.*"+ matches +"agent.qa"+ and +"agent.qa.response.chunk"+).
      # - A degenerate channel with a trailing dot (e.g., +"agent."+ against pattern +"agent.*"+)
      #   also matches, as it begins with the prefix +"agent."+ — callers should avoid publishing
      #   to channels with trailing dots in practice.
      #
      # @param pattern [String] subscription pattern
      # @param channel [String] event channel name
      # @return [Boolean]
      def self.match?(pattern, channel)
        return true if pattern == "*"
        return true if pattern == channel

        if pattern.end_with?(".*")
          prefix = pattern[0..-3] # strip trailing .*
          channel.start_with?("#{prefix}.")
        else
          false
        end
      end
    end
  end
end
