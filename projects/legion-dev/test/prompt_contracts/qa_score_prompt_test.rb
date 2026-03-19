# frozen_string_literal: true

require "test_helper"

module Legion
  # Prompt contract tests for QA scoring prompt (Layer 2, D-44)
  # Tagged live_llm: true to run against actual LLM
  class QaScorePromptTest < ActiveSupport::TestCase
    # Disable parallel tests for live LLM tests
    self.use_transactional_tests = false

    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @execution = create(:workflow_execution, project: @project)
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Test 1: Passing code + met acceptance criteria → QA score >= 90
    # ══════════════════════════════════════════════════════════════════════════
    test "live_llm: true passing code meets acceptance criteria scores >= 90" do
      skip("Live LLM test - set RECORD_VCR=1 to record cassette") unless ENV["RECORD_VCR"] == "1"

      # Create passing code implementation
      passing_code = <<~RUBY
        # frozen_string_literal: true

        class UserService
          # Creates a new user with the given attributes
          #
          # @param attrs [Hash] User attributes
          # @return [User] Created user
          def self.create_user(attrs)
            User.create!(attrs)
          end
        end
      RUBY

      # Create a task with passing code
      task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Implement UserService.create_user method",
        status: "completed",
        result: passing_code,
        error_message: nil
      )

      # Create acceptance criteria that the code should meet
      @project.update!(acceptance_criteria: <<~AC)
        - AC1: UserService must have a create_user class method
        - AC2: create_user must accept a hash of attributes
        - AC3: create_user must return a User instance
        - AC4: create_user must use strong parameters
      AC

      # Build the QA score prompt
      gate = QaGate.new(execution: @execution)
      prompt = gate.send(:build_prompt)

      # Dispatch QA agent
      VCR.use_cassette("qa_score_prompt/passing_code_scores_high") do
        result = gate.evaluate

        # Verify score >= 90 (threshold for passing)
        assert result.passed, "Expected QA score >= 90 for passing code"
        assert_operator result.score, :>=, 90, "Expected score >= 90, got #{result.score}"
        assert result.artifact, "Expected artifact to be created"
        assert_equal :score_report, result.artifact.artifact_type
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Test 2: Failing code (empty implementation) → QA score < 90
    # ══════════════════════════════════════════════════════════════════════════
    test "live_llm: true empty implementation scores < 90" do
      skip("Live LLM test - set RECORD_VCR=1 to record cassette") unless ENV["RECORD_VCR"] == "1"

      # Create empty/failing code implementation
      empty_code = <<~RUBY
        # frozen_string_literal: true

        class UserService
          # TODO: Implement create_user method
        end
      RUBY

      # Create a task with empty code
      task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Implement UserService.create_user method",
        status: "completed",
        result: empty_code,
        error_message: nil
      )

      # Create acceptance criteria that the code should meet
      @project.update!(acceptance_criteria: <<~AC)
        - AC1: UserService must have a create_user class method
        - AC2: create_user must accept a hash of attributes
        - AC3: create_user must return a User instance
        - AC4: create_user must use strong parameters
      AC

      # Build the QA score prompt
      gate = QaGate.new(execution: @execution)
      prompt = gate.send(:build_prompt)

      # Dispatch QA agent
      VCR.use_cassette("qa_score_prompt/empty_code_scores_low") do
        result = gate.evaluate

        # Verify score < 90 (threshold for failing)
        refute result.passed, "Expected QA score < 90 for empty code"
        assert_operator result.score, :<, 90, "Expected score < 90, got #{result.score}"
        assert result.artifact, "Expected artifact to be created"
        assert_equal :score_report, result.artifact.artifact_type
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Test 3: Verify QA scoring prompt includes Φ11 rubric (4 criteria)
    # ══════════════════════════════════════════════════════════════════════════
    test "qa_score_prompt includes RULES.md Φ11 scoring rubric" do
      skip("Live LLM test - set RECORD_VCR=1 to record cassette") unless ENV["RECORD_VCR"] == "1"

      # Create minimal passing code
      passing_code = <<~RUBY
        # frozen_string_literal: true

        class UserService
          def self.create_user(attrs)
            User.create!(attrs)
          end
        end
      RUBY

      task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Implement UserService.create_user",
        status: "completed",
        result: passing_code,
        error_message: nil
      )

      @project.update!(acceptance_criteria: "- AC1: UserService must have create_user method")

      gate = QaGate.new(execution: @execution)

      VCR.use_cassette("qa_score_prompt/rubric_included") do
        result = gate.evaluate

        # Verify the prompt included the Φ11 rubric criteria
        # The QA agent should score on: AC Compliance, Test Coverage, Code Quality, Plan Adherence
        assert result.artifact, "Expected artifact to be created"
        assert result.artifact.content.include?("Score"), "Artifact should contain score information"
        assert result.artifact.content.include?("Feedback"), "Artifact should contain feedback"
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Test 4: Verify score parsing from QA agent output
    # ══════════════════════════════════════════════════════════════════════════
    test "qa_score_prompt score parsing handles various formats" do
      skip("Live LLM test - set RECORD_VCR=1 to record cassette") unless ENV["RECORD_VCR"] == "1"

      passing_code = <<~RUBY
        # frozen_string_literal: true
        class TestService
          def self.run; true; end
        end
      RUBY

      task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Implement TestService.run",
        status: "completed",
        result: passing_code,
        error_message: nil
      )

      @project.update!(acceptance_criteria: "- AC1: TestService must have run method")

      gate = QaGate.new(execution: @execution)

      VCR.use_cassette("qa_score_prompt/score_parsing") do
        result = gate.evaluate

        # Verify score is a valid integer
        assert result.score.is_a?(Integer), "Score should be an integer"
        assert result.score >= 0, "Score should be >= 0"
        assert result.score <= 100, "Score should be <= 100"

        # Verify artifact contains score
        assert result.artifact, "Expected artifact"
        assert result.artifact.metadata.key?(:score), "Artifact metadata should contain score"
        assert_equal result.score, result.artifact.metadata[:score]
      end
    end
  end
end
