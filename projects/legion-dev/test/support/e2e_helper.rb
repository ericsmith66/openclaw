# frozen_string_literal: true

module Legion
  module E2EHelper
    # Creates a test project with a unique path
    def create_test_project(name: "test-project")
      path = Rails.root.join("tmp/test_projects/#{name}_#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(path)
      Project.create!(name: name, path: path.to_s)
    end

    # Imports the ROR team from fixtures
    # Returns the AgentTeam record
    def import_ror_team(project)
      fixture_path = Rails.root.join("test/fixtures/aider_desk/valid_team")
      result = TeamImportService.call(
        aider_desk_path: fixture_path.to_s,
        project_path: project.path.to_s,
        team_name: "ROR",
        dry_run: false
      )

      raise "Team import failed: #{result.errors.join(', ')}" unless result.errors.empty?

      result.team
    end

    # Verifies agent profile has expected attributes
    def verify_profile_attributes(profile, expected)
      assert_equal expected[:provider], profile.provider if expected[:provider]
      assert_equal expected[:model], profile.model if expected[:model]
      assert_equal expected[:max_iterations], profile.max_iterations if expected[:max_iterations]

      # Verify tool_approvals structure
      if expected[:tool_approvals]
        expected[:tool_approvals].each do |tool, approval|
          assert_equal approval, profile.tool_approvals[tool],
            "Expected tool_approvals[#{tool}] = #{approval}, got #{profile.tool_approvals[tool]}"
        end
      end

      # Verify custom instructions present
      if expected[:custom_instructions_contains]
        assert_includes profile.custom_instructions, expected[:custom_instructions_contains],
          "Expected custom_instructions to contain '#{expected[:custom_instructions_contains]}'"
      end
    end

    # Verifies event trail completeness
    def verify_event_trail(workflow_run, expected_event_types: [])
      events = workflow_run.workflow_events.order(:created_at)

      assert_operator events.count, :>, 0, "Expected at least one event"

      expected_event_types.each do |type|
        assert events.exists?(event_type: type), "Expected event type #{type}"
      end

      # Verify chronological ordering
      timestamps = events.pluck(:created_at)
      assert_equal timestamps, timestamps.sort, "Events should be chronologically ordered"
    end

    # Verifies task attributes and dependencies
    def verify_task_structure(tasks)
      tasks.each do |task|
        assert_includes %w[test code review debug], task.task_type,
          "Task type #{task.task_type} not in expected set"

        if task.files_score
          assert_operator task.files_score, :>=, 1
          assert_operator task.files_score, :<=, 4
        end

        if task.concepts_score
          assert_operator task.concepts_score, :>=, 1
          assert_operator task.concepts_score, :<=, 4
        end

        if task.dependencies_score
          assert_operator task.dependencies_score, :>=, 1
          assert_operator task.dependencies_score, :<=, 4
        end

        assert_not_nil task.total_score if task.files_score && task.concepts_score && task.dependencies_score
      end
    end
  end
end
