# frozen_string_literal: true

require "test_helper"

module Legion
  class DecompositionParserTest < ActiveSupport::TestCase
    def valid_task_json
      [
        {
          position: 1,
          type: "test",
          prompt: "Write tests for User model",
          agent: "rails-lead",
          files_score: 2,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [],
          notes: "Test task"
        },
        {
          position: 2,
          type: "code",
          prompt: "Create User model",
          agent: "rails-lead",
          files_score: 2,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 1 ],
          notes: "Implementation"
        }
      ].to_json
    end

    test "parses valid json array" do
      result = DecompositionParser.call(response_text: valid_task_json)

      assert_equal 2, result.tasks.size
      assert_equal [], result.errors
      assert_equal 1, result.tasks.first[:position]
      assert_equal "test", result.tasks.first[:type]
      assert_equal 4, result.tasks.first[:total_score]
    end

    test "handles json wrapped in code fences" do
      wrapped = "```json\n#{valid_task_json}\n```"
      result = DecompositionParser.call(response_text: wrapped)

      assert_equal 2, result.tasks.size
      assert_equal [], result.errors
    end

    test "handles trailing commas" do
      json_with_trailing = <<~JSON
        [
          {
            "position": 1,
            "type": "test",
            "prompt": "test",
            "agent": "rails-lead",
            "files_score": 1,
            "concepts_score": 1,
            "dependencies_score": 1,
            "depends_on": [],
          }
        ]
      JSON

      result = DecompositionParser.call(response_text: json_with_trailing)

      assert_equal 1, result.tasks.size
      assert_equal [], result.errors
    end

    test "validates required fields missing" do
      json = [
        {
          position: 1,
          type: "test",
          # missing prompt
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: []
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_equal 0, result.tasks.size
      assert_includes result.errors.first, "missing required fields"
      assert_includes result.errors.first, "prompt"
    end

    test "validates required fields all present" do
      result = DecompositionParser.call(response_text: valid_task_json)

      assert_equal [], result.errors
      assert_equal 2, result.tasks.size
    end

    test "validates score ranges within bounds" do
      json = [
        {
          position: 1,
          type: "test",
          prompt: "test",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 4,
          dependencies_score: 2,
          depends_on: []
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_equal [], result.errors
      assert_equal 1, result.tasks.size
    end

    test "validates score ranges out of bounds" do
      json = [
        {
          position: 1,
          type: "test",
          prompt: "test",
          agent: "rails-lead",
          files_score: 5,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: []
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_equal 0, result.tasks.size
      assert_includes result.errors.first, "files_score must be 1-4"
    end

    test "computes total score correctly" do
      result = DecompositionParser.call(response_text: valid_task_json)

      assert_equal 4, result.tasks.first[:total_score] # 2+1+1
      assert_equal 4, result.tasks.last[:total_score]  # 2+1+1
    end

    test "detects invalid dependency references" do
      json = [
        {
          position: 1,
          type: "test",
          prompt: "test",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 99 ] # non-existent
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_equal 0, result.tasks.size
      assert_includes result.errors.first, "depends on non-existent task 99"
    end

    test "detects dependency cycles simple" do
      json = [
        {
          position: 1,
          type: "test",
          prompt: "test",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 2 ]
        },
        {
          position: 2,
          type: "code",
          prompt: "code",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 1 ]
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_includes result.errors.first, "Dependency cycle detected"
    end

    test "detects dependency cycles complex" do
      json = [
        {
          position: 1,
          type: "test",
          prompt: "test",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 3 ]
        },
        {
          position: 2,
          type: "code",
          prompt: "code",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 1 ]
        },
        {
          position: 3,
          type: "review",
          prompt: "review",
          agent: "qa",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 2 ]
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_includes result.errors.first, "Dependency cycle detected"
    end

    test "flags tasks over threshold" do
      json = [
        {
          position: 1,
          type: "test",
          prompt: "test",
          agent: "rails-lead",
          files_score: 3,
          concepts_score: 2,
          dependencies_score: 3,
          depends_on: []
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_equal 1, result.tasks.size
      assert_equal [], result.errors
      assert_includes result.warnings.first, "total_score 8 > threshold 6"
    end

    test "identifies parallel groups" do
      # This is tested via integration — parser just provides tasks,
      # service detects parallel groups
      result = DecompositionParser.call(response_text: valid_task_json)

      assert_equal 2, result.tasks.size
      # Task 1 has no dependencies
      assert_equal [], result.tasks.first[:depends_on]
      # Task 2 depends on task 1
      assert_equal [ 1 ], result.tasks.last[:depends_on]
    end

    test "returns errors for unparseable json" do
      result = DecompositionParser.call(response_text: "not json at all")

      assert_equal 0, result.tasks.size
      assert_includes result.errors.first, "No valid JSON found"
    end

    test "handles empty json array" do
      result = DecompositionParser.call(response_text: "[]")

      assert_equal 0, result.tasks.size
      assert_includes result.warnings.first, "Empty task list"
    end

    test "validates task type enum" do
      json = [
        {
          position: 1,
          type: "invalid_type",
          prompt: "test",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: []
        }
      ].to_json

      result = DecompositionParser.call(response_text: json)

      assert_equal 0, result.tasks.size
      assert_includes result.errors.first, "invalid type 'invalid_type'"
    end

    test "handles non json preamble and suffix" do
      response = <<~TEXT
        Here is the task decomposition:

        #{valid_task_json}

        Let me know if you'd like any changes!
      TEXT

      result = DecompositionParser.call(response_text: response)

      assert_equal 2, result.tasks.size
      assert_equal [], result.errors
    end
  end
end
