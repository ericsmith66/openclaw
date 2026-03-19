# frozen_string_literal: true

require "json"
require "securerandom"
require "fileutils"

module AgentDesk
  module Memory
    # Persistent memory storage with JSON file persistence and keyword-based retrieval.
    #
    # @example
    #   store = MemoryStore.new(storage_path: "/tmp/memories.json")
    #   memory = store.store(type: "user-preference", content: "prefers dark theme")
    #   results = store.retrieve(query: "dark theme")
    #
    class MemoryStore
      # Immutable memory record.
      Memory = Data.define(:id, :type, :content, :timestamp, :project_id)

      # @param storage_path [String] absolute path to the JSON storage file
      def initialize(storage_path:)
        @storage_path = storage_path
        @memories = load_from_disk
      end

      # Store a new memory.
      #
      # @param type [String] memory type ("task", "user-preference", "code-pattern")
      # @param content [String] memory content (free text)
      # @param project_id [String, nil] optional project identifier for scoping
      # @return [Memory] the created memory record
      # @raise [ArgumentError] if type or content is nil
      def store(type:, content:, project_id: nil)
        raise ArgumentError, "type cannot be nil" if type.nil?
        raise ArgumentError, "content cannot be nil" if content.nil?

        memory = Memory.new(
          id: SecureRandom.uuid,
          type: type,
          content: content,
          timestamp: Time.now.to_i,
          project_id: project_id
        )
        @memories << memory
        save_to_disk
        memory
      end

      # Retrieve memories matching the query via simple keyword matching.
      #
      # @param query [String, nil] search query (split into whitespace‑separated terms).
      #   If nil, treated as empty string (no matches).
      # @param limit [Integer] maximum number of memories to return (default: 3)
      # @param project_id [String, nil] optional project identifier to filter by
      # @return [Array<Memory>] matching memories, ordered by relevance (highest first)
      def retrieve(query:, limit: 3, project_id: nil)
        candidates = @memories
        candidates = candidates.select { |m| m.project_id == project_id } if project_id

        query_terms = query.to_s.downcase.split(/\s+/)
        scored = candidates.map do |m|
          score = query_terms.count { |term| m.content.to_s.downcase.include?(term) }
          [ m, score ]
        end
        scored.select { |_, s| s > 0 }
               .sort_by { |_, s| -s }
               .first(limit)
               .map(&:first)
      end

      # Delete a memory by its ID.
      #
      # @param id [String] UUID of the memory to delete
      # @return [void]
      def delete(id:)
        @memories.reject! { |m| m.id == id }
        save_to_disk
      end

      # Update the content of an existing memory.
      #
      # @param id [String] UUID of the memory to update
      # @param content [String] new content
      # @return [Memory, nil] updated memory record, or nil if not found
      # @raise [ArgumentError] if content is nil
      def update(id:, content:)
        raise ArgumentError, "content cannot be nil" if content.nil?

        memory = @memories.find { |m| m.id == id }
        return nil unless memory

        idx = @memories.index(memory)
        @memories[idx] = Memory.new(
          id: memory.id,
          type: memory.type,
          content: content,
          timestamp: Time.now.to_i,
          project_id: memory.project_id
        )
        save_to_disk
        @memories[idx]
      end

      # List memories, optionally filtered by type and/or project ID.
      #
      # @param type [String, nil] filter by memory type
      # @param project_id [String, nil] filter by project identifier
      # @return [Array<Memory>] matching memories
      def list(type: nil, project_id: nil)
        result = @memories
        result = result.select { |m| m.type == type } if type
        result = result.select { |m| m.project_id == project_id } if project_id
        result
      end

      private

      # Load memories from disk. Returns empty array on any error.
      #
      # @return [Array<Memory>]
      def load_from_disk
        return [] unless File.exist?(@storage_path)

        data = JSON.parse(File.read(@storage_path), symbolize_names: true)
        data.map { |d| Memory.new(**d) }
      rescue JSON::ParserError, Errno::ENOENT, Errno::EACCES, EncodingError => e
        warn "MemoryStore: failed to load #{@storage_path}: #{e.message}"
        []
      end

      # Persist memories to disk atomically (write to temp file, then rename).
      #
      # @return [void]
      def save_to_disk
        FileUtils.mkdir_p(File.dirname(@storage_path))
        temp_path = "#{@storage_path}.tmp.#{Process.pid}"
        File.write(temp_path, JSON.pretty_generate(@memories.map(&:to_h)))
        File.rename(temp_path, @storage_path)
      rescue Errno::EACCES, Errno::ENOSPC => e
        warn "MemoryStore: failed to save #{@storage_path}: #{e.message}"
        raise
      end
    end
  end
end
