# frozen_string_literal: true

module AgentDesk
  module Tools
    # A registry of tools keyed by their fully-qualified name (group---name).
    #
    # ToolSet is an Enumerable collection of {BaseTool} objects. It supports
    # adding, merging, filtering by approval policy, and serializing to
    # OpenAI-compatible function definitions.
    #
    # Thread-safety note: ToolSet is safe for concurrent read access. Write
    # access (add, merge!, filter_by_approvals) is always single-threaded
    # during setup or within a single Runner loop iteration.
    class ToolSet
      include Enumerable

      # Creates an empty ToolSet.
      def initialize
        @tools = {}
      end

      # Adds a tool to this set, keyed by its full_name.
      #
      # @param tool [BaseTool] the tool to add
      # @return [BaseTool] the added tool
      def add(tool)
        @tools[tool.full_name] = tool
      end

      # Merges all tools from another ToolSet into this one.
      #
      # @param other_tool_set [ToolSet] the set to merge from
      # @return [self]
      def merge!(other_tool_set)
        other_tool_set.each { |tool| add(tool) }
        self
      end

      # Retrieves a tool by its fully-qualified name.
      #
      # @param full_name [String] e.g. "power---bash"
      # @return [BaseTool, nil] the tool or nil if not found
      def [](full_name)
        @tools[full_name]
      end

      # Iterates over all tools in the set.
      #
      # @yield [BaseTool] each tool
      def each(&block)
        @tools.values.each(&block)
      end

      # Returns the number of tools in the set.
      #
      # @return [Integer]
      def size
        @tools.size
      end

      # Removes tools that have a NEVER approval state in the given approvals map.
      # Tools with ALWAYS, ASK, or absent entries are kept.
      #
      # This mutates the ToolSet in place. The Runner creates a fresh ToolSet
      # per iteration, so mutation is safe.
      #
      # @param tool_approvals [Hash{String => String}] map of full_name → approval state
      # @return [self]
      def filter_by_approvals(tool_approvals)
        rejected = @tools.keys.select do |full_name|
          tool_approvals[full_name] == ToolApprovalState::NEVER
        end
        rejected.each { |full_name| @tools.delete(full_name) }
        self
      end

      # Serializes all tools in the set to OpenAI-compatible function definition hashes.
      #
      # @return [Array<Hash>] array of function definitions
      def to_function_definitions
        @tools.values.map(&:to_function_definition)
      end
    end
  end
end
