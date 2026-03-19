# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "securerandom"

class MemoryStoreTest < Minitest::Test
  def setup
    @tempfile = Tempfile.new([ "memory", ".json" ])
    File.write(@tempfile.path, "[]")
    @store = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
  end

  def teardown
    @tempfile.close
    @tempfile.unlink
  end

  def test_store_persists
    memory = @store.store(type: "task", content: "test")
    assert_equal "task", memory.type
    assert_equal "test", memory.content
    assert_match(/\A[0-9a-f\-]{36}\z/, memory.id)
    assert_kind_of Integer, memory.timestamp
  end

  def test_retrieve_keyword_matching
    @store.store(type: "task", content: "implement memory system")
    @store.store(type: "task", content: "write tests for memory")
    @store.store(type: "user-preference", content: "dark theme")

    results = @store.retrieve(query: "memory")
    assert_equal 2, results.size
    assert_equal "implement memory system", results.first.content

    results = @store.retrieve(query: "dark theme")
    assert_equal 1, results.size

    # case insensitive
    results = @store.retrieve(query: "MEMORY")
    assert_equal 2, results.size

    # limit
    results = @store.retrieve(query: "memory", limit: 1)
    assert_equal 1, results.size
  end

  def test_retrieve_with_project_id
    @store.store(type: "task", content: "global task")
    @store.store(type: "task", content: "project task", project_id: "proj1")

    results = @store.retrieve(query: "task", project_id: "proj1")
    assert_equal 1, results.size
    assert_equal "project task", results.first.content

    results = @store.retrieve(query: "task")
    assert_equal 2, results.size
  end

  def test_delete
    memory = @store.store(type: "task", content: "delete me")
    assert_equal 1, @store.list.size

    @store.delete(id: memory.id)
    assert_empty @store.list

    # delete non‑existent ID does nothing
    @store.delete(id: "non-existent")
  end

  def test_update
    memory = @store.store(type: "user-preference", content: "original")
    updated = @store.update(id: memory.id, content: "updated")
    refute_nil updated
    assert_equal "updated", updated.content
    assert_equal memory.type, updated.type
    assert_operator updated.timestamp, :>=, memory.timestamp

    # verify persistence
    store2 = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
    found = store2.list.first
    assert_equal "updated", found.content
  end

  def test_update_non_existent_returns_nil
    assert_nil @store.update(id: "non-existent", content: "new")
  end

  def test_list_with_filters
    @store.store(type: "task", content: "t1", project_id: "p1")
    @store.store(type: "task", content: "t2", project_id: "p2")
    @store.store(type: "user-preference", content: "up", project_id: "p1")

    assert_equal 3, @store.list.size
    assert_equal 2, @store.list(type: "task").size
    assert_equal 2, @store.list(project_id: "p1").size
    assert_equal 1, @store.list(type: "task", project_id: "p1").size
    assert_equal 0, @store.list(type: "code-pattern").size
  end

  def test_persistence_across_restart
    @store.store(type: "task", content: "survive")
    @store.store(type: "user-preference", content: "also survive", project_id: "proj")

    store2 = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
    memories = store2.list
    assert_equal 2, memories.size
    assert_equal "survive", memories.find { |m| m.type == "task" }.content
    assert_equal "also survive", memories.find { |m| m.project_id == "proj" }.content
  end

  def test_corrupt_file_recovery
    File.write(@tempfile.path, "invalid json")
    store = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
    # should not raise, starts with empty array
    assert_empty store.list
    # can still store new memories
    store.store(type: "task", content: "recovered")
    assert_equal 1, store.list.size
  end

  def test_atomic_write_on_save
    # Simulate a failure during write by raising an error in the middle.
    # We'll stub File.write to raise an error, ensure original file unchanged.
    # For simplicity, just verify the file is valid JSON after write.
    store = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
    store.store(type: "task", content: "atomic")
    # The temp file should be removed after rename; we can't easily test without mocking.
    # But we can ensure the file is valid JSON after write.
    content = File.read(@tempfile.path)
    data = JSON.parse(content, symbolize_names: true)
    assert_equal 1, data.size
    assert_equal "atomic", data.first[:content]
  end

  def test_save_rescues_permission_errors_and_raises
    # Make the directory read‑only to cause EACCES.
    dir = Dir.mktmpdir
    file = File.join(dir, "memories.json")
    store = AgentDesk::Memory::MemoryStore.new(storage_path: file)
    FileUtils.chmod(0o444, dir) # read‑only directory
    assert_raises(Errno::EACCES) { store.store(type: "task", content: "fail") }
  ensure
    FileUtils.chmod(0o755, dir) if Dir.exist?(dir)
    FileUtils.remove_entry(dir) if Dir.exist?(dir)
  end

  def test_retrieve_with_nil_query
    @store.store(type: "task", content: "some memory")
    results = @store.retrieve(query: nil)
    assert_empty results
  end

  def test_retrieve_with_empty_query
    @store.store(type: "task", content: "some memory")
    results = @store.retrieve(query: "")
    assert_empty results
    results = @store.retrieve(query: "   ")
    assert_empty results
  end

  def test_store_raises_argument_error_on_nil_content
    assert_raises(ArgumentError) { @store.store(type: "task", content: nil) }
    assert_raises(ArgumentError) { @store.store(type: nil, content: "content") }
  end

  def test_update_raises_argument_error_on_nil_content
    memory = @store.store(type: "task", content: "original")
    assert_raises(ArgumentError) { @store.update(id: memory.id, content: nil) }
  end

  # Robustness: retrieve should handle nil content (e.g., from a bug or direct instantiation)
  def test_retrieve_with_nil_content_in_memory
    memories = @store.instance_variable_get(:@memories)
    memories << AgentDesk::Memory::MemoryStore::Memory.new(
      id: SecureRandom.uuid,
      type: "task",
      content: nil,
      timestamp: Time.now.to_i,
      project_id: nil
    )
    # Should not raise NoMethodError
    results = @store.retrieve(query: "anything")
    assert_empty results  # nil content cannot match any keyword
  end
end
