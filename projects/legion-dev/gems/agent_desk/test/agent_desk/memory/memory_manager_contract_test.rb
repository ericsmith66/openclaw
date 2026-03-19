# frozen_string_literal: true

require "test_helper"
require "tempfile"

class MemoryManagerContractTest < Minitest::Test
  def setup
    @tempfile = Tempfile.new([ "memory", ".json" ])
    File.write(@tempfile.path, "[]")
    @store = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
  end

  def teardown
    @tempfile.close
    @tempfile.unlink
  end

  def test_store_persists_memory
    memory = @store.store(type: "user-preference", content: "prefers dark theme")
    assert_equal "user-preference", memory.type
    assert_equal "prefers dark theme", memory.content
    assert_match(/\A[0-9a-f\-]{36}\z/, memory.id)
    assert_kind_of Integer, memory.timestamp
    assert_nil memory.project_id

    # Reload store from same file
    store2 = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
    memories = store2.list
    assert_equal 1, memories.size
    assert_equal memory.id, memories.first.id
  end

  def test_retrieve_returns_relevant_memories
    @store.store(type: "task", content: "implement memory system")
    @store.store(type: "user-preference", content: "dark theme preferred")
    @store.store(type: "code-pattern", content: "use Data.define for immutable records")

    results = @store.retrieve(query: "memory system")
    assert_equal 1, results.size
    assert_equal "implement memory system", results.first.content

    results = @store.retrieve(query: "theme")
    assert_equal 1, results.size
    assert_equal "dark theme preferred", results.first.content

    results = @store.retrieve(query: "data define")
    assert_equal 1, results.size
    assert_equal "use Data.define for immutable records", results.first.content

    # limit works
    @store.store(type: "task", content: "another memory system task")
    results = @store.retrieve(query: "memory", limit: 1)
    assert_equal 1, results.size
  end

  def test_delete_removes_memory_by_id
    memory = @store.store(type: "task", content: "delete me")
    assert_equal 1, @store.list.size

    @store.delete(id: memory.id)
    assert_empty @store.list

    # deleting non‑existent ID is a no‑op
    @store.delete(id: "non-existent")
  end

  def test_update_modifies_memory_content
    memory = @store.store(type: "user-preference", content: "original")
    updated = @store.update(id: memory.id, content: "updated content")
    refute_nil updated
    assert_equal "updated content", updated.content
    assert_equal memory.type, updated.type
    assert_nil updated.project_id
    assert_operator updated.timestamp, :>=, memory.timestamp

    # non‑existent ID returns nil
    assert_nil @store.update(id: "non-existent", content: "new")
  end

  def test_list_returns_all_memories_filtered
    @store.store(type: "task", content: "task 1", project_id: "proj1")
    @store.store(type: "task", content: "task 2", project_id: "proj2")
    @store.store(type: "user-preference", content: "pref", project_id: "proj1")

    all = @store.list
    assert_equal 3, all.size

    by_type = @store.list(type: "task")
    assert_equal 2, by_type.size

    by_project = @store.list(project_id: "proj1")
    assert_equal 2, by_project.size

    combined = @store.list(type: "task", project_id: "proj1")
    assert_equal 1, combined.size
  end
end
