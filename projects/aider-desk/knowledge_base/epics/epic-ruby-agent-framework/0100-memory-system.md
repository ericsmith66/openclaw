# PRD-0100: Memory System

**PRD ID**: PRD-0100
**Status**: Draft
**Priority**: Medium
**Created**: 2026-02-26
**Milestone**: M5 (Skills & Memory)
**Depends On**: PRD-0020

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/tools/memory.ts` — `createMemoryToolset` (store, retrieve, delete, list, update tools)
- `src/main/memory/memory-manager.ts` — Vector storage, embedding, retrieval
- `src/common/tools.ts` — `MEMORY_TOOL_*` constants and descriptions

**Output Files** (Ruby):
- `lib/agent_desk/memory/memory_manager.rb` — Storage and retrieval engine
- `lib/agent_desk/memory/memory_store.rb` — Persistence backend (JSON file or SQLite)
- `lib/agent_desk/tools/memory_tools.rb` — Tool group creation
- `spec/agent_desk/memory/memory_manager_spec.rb`
- `spec/agent_desk/tools/memory_tools_spec.rb`

---

## 1. Problem Statement

The agent needs to persist information across sessions — user preferences, architectural decisions, reusable patterns. AiderDesk uses a vector-based memory system with:
- **store_memory** — Save a new memory with type and content
- **retrieve_memory** — Semantic search across stored memories
- **delete_memory** — Remove a specific memory by ID
- **list_memories** — List all memories (with optional filtering)
- **update_memory** — Modify an existing memory

---

## 2. Design

### 2.1 Memory Storage

For the Ruby gem, start with a simple JSON file store. Semantic search can be approximated with keyword matching initially; a vector embedding backend (e.g., via OpenAI embeddings API) is a future enhancement.

```ruby
# lib/agent_desk/memory/memory_store.rb
module AgentDesk
  module Memory
    class MemoryStore
      Memory = Data.define(:id, :type, :content, :timestamp, :project_id)

      def initialize(storage_path:)
        @storage_path = storage_path
        @memories = load_from_disk
      end

      def store(type:, content:, project_id: nil)
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

      def retrieve(query:, limit: 3, project_id: nil)
        candidates = @memories
        candidates = candidates.select { |m| m.project_id == project_id } if project_id

        # Simple keyword search (upgrade to vector search later)
        query_terms = query.downcase.split(/\s+/)
        scored = candidates.map do |m|
          score = query_terms.count { |term| m.content.downcase.include?(term) }
          [m, score]
        end
        scored.sort_by { |_m, s| -s }.first(limit).map(&:first).select { |_m, s| s > 0 }.map(&:first)
      end

      def delete(id:)
        @memories.reject! { |m| m.id == id }
        save_to_disk
      end

      def update(id:, content:)
        memory = @memories.find { |m| m.id == id }
        return nil unless memory

        idx = @memories.index(memory)
        @memories[idx] = Memory.new(
          id: memory.id, type: memory.type,
          content: content, timestamp: Time.now.to_i,
          project_id: memory.project_id
        )
        save_to_disk
        @memories[idx]
      end

      def list(type: nil, project_id: nil)
        result = @memories
        result = result.select { |m| m.type == type } if type
        result = result.select { |m| m.project_id == project_id } if project_id
        result
      end

      private

      def load_from_disk
        return [] unless File.exist?(@storage_path)
        data = JSON.parse(File.read(@storage_path), symbolize_names: true)
        data.map { |d| Memory.new(**d) }
      rescue StandardError
        []
      end

      def save_to_disk
        FileUtils.mkdir_p(File.dirname(@storage_path))
        File.write(@storage_path, JSON.pretty_generate(@memories.map(&:to_h)))
      end
    end
  end
end
```

### 2.2 Memory Tools

```ruby
# lib/agent_desk/tools/memory_tools.rb
module AgentDesk
  module Tools
    module MemoryTools
      def self.create(memory_store:, project_id: nil)
        Tools.build_group(MEMORY_TOOL_GROUP_NAME) do
          tool MEMORY_TOOL_STORE,
               description: TOOL_DESCRIPTIONS[MEMORY_TOOL_STORE],
               input_schema: {
                 properties: {
                   type: { type: 'string', enum: %w[task user-preference code-pattern] },
                   content: { type: 'string' }
                 },
                 required: %w[type content]
               } do |args, _ctx|
            memory = memory_store.store(type: args['type'], content: args['content'], project_id: project_id)
            { id: memory.id, stored: true }
          end

          tool MEMORY_TOOL_RETRIEVE,
               description: TOOL_DESCRIPTIONS[MEMORY_TOOL_RETRIEVE],
               input_schema: {
                 properties: {
                   query: { type: 'string' },
                   limit: { type: 'integer', default: 3 }
                 },
                 required: ['query']
               } do |args, _ctx|
            results = memory_store.retrieve(query: args['query'], limit: args.fetch('limit', 3), project_id: project_id)
            results.map(&:to_h)
          end

          tool MEMORY_TOOL_DELETE,
               description: TOOL_DESCRIPTIONS[MEMORY_TOOL_DELETE],
               input_schema: {
                 properties: { id: { type: 'string' } },
                 required: ['id']
               } do |args, _ctx|
            memory_store.delete(id: args['id'])
            { deleted: true }
          end

          tool MEMORY_TOOL_LIST,
               description: TOOL_DESCRIPTIONS[MEMORY_TOOL_LIST],
               input_schema: {
                 properties: {
                   type: { type: 'string' }
                 },
                 required: []
               } do |args, _ctx|
            memory_store.list(type: args['type'], project_id: project_id).map(&:to_h)
          end

          tool MEMORY_TOOL_UPDATE,
               description: TOOL_DESCRIPTIONS[MEMORY_TOOL_UPDATE],
               input_schema: {
                 properties: {
                   id: { type: 'string' },
                   content: { type: 'string' }
                 },
                 required: %w[id content]
               } do |args, _ctx|
            updated = memory_store.update(id: args['id'], content: args['content'])
            updated ? { updated: true, memory: updated.to_h } : { updated: false, error: 'Memory not found' }
          end
        end
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ `MemoryStore#store` persists a memory to disk (JSON)
- ✅ `MemoryStore#retrieve` returns relevant memories by keyword matching
- ✅ `MemoryStore#delete` removes a memory by ID
- ✅ `MemoryStore#update` modifies an existing memory's content
- ✅ `MemoryStore#list` returns all memories, optionally filtered by type
- ✅ Memory tools integrate with the tool framework (PRD-0020)
- ✅ Memories survive process restart (loaded from disk on init)

---

## 4. Future Enhancements

- **Vector embeddings**: Use OpenAI embeddings API for true semantic retrieval
- **SQLite backend**: Replace JSON file for better concurrent access
- **TTL / expiration**: Auto-expire old memories
- **Scoped memories**: Per-task vs per-project vs global

---

**Next**: PRD-0110 (Todo, Task, & Helper Tool Groups) completes the remaining tool groups.
