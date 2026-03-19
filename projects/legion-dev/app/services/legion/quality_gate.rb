# frozen_string_literal: true

module Legion
  # Base class for quality gate evaluations (QA scoring, Architect review, etc.)
  #
  # QualityGate implements the template method pattern for gate evaluation:
  # 1. Build prompt via PromptBuilder
  # 2. Dispatch agent via DispatchService
  # 3. Parse score via ScoreParser
  # 4. Create Artifact
  # 5. Return GateResult
  #
  # Subclasses must define:
  # - gate_name (string identifier)
  # - prompt_template_phase (symbol for PromptBuilder)
  # - agent_role (string identifier for team membership)
  # - default_threshold (integer score threshold)
  #
  # @example Subclass implementation
  #   class QAGate < Legion::QualityGate
  #     def gate_name; "qa"; end
  #     def prompt_template_phase; :qa_score; end
  #     def agent_role; "qa"; end
  #     def default_threshold; 90; end
  #   end
  #
  # @see ScoreParser
  # @see PromptBuilder
  # @see DispatchService
  class QualityGate
    # Result struct for gate evaluation
    GateResult = Struct.new(:passed, :score, :feedback, :artifact, keyword_init: true)

    # Registry of all QualityGate subclasses
    @registry = []

    class << self
      # Returns registry of all registered gate subclasses
      #
      # @return [Array<Class>] Array of QualityGate subclasses
      def registry
        @registry
      end

      # Registers a subclass in the gate registry
      #
      # @param subclass [Class] The subclass to register
      def register(subclass)
        @registry << subclass
      end
    end

    # Initialize with execution and optional workflow_run
    #
    # @param execution [WorkflowExecution] The workflow execution context
    # @param workflow_run [WorkflowRun, nil] Optional workflow run (for ArchitectGate)
    def initialize(execution:, workflow_run: nil)
      @execution = execution
      @workflow_run = workflow_run
    end

    # Evaluate the quality gate
    #
    # @param threshold [Integer, nil] Optional threshold override
    # @return [GateResult] Result with passed status, score, feedback, and artifact
    def evaluate(threshold: nil)
      build_prompt
      dispatch_agent
      parse_score
      create_artifact
      build_result(threshold)
    rescue StandardError => e
      handle_error(e)
    end

    # Subclass contract: gate name (string identifier)
    #
    # @return [String]
    def gate_name
      raise NotImplementedError, "Subclass must implement #gate_name"
    end

    # Subclass contract: prompt template phase symbol
    #
    # @return [Symbol]
    def prompt_template_phase
      raise NotImplementedError, "Subclass must implement #prompt_template_phase"
    end

    # Subclass contract: agent role identifier
    #
    # @return [String]
    def agent_role
      raise NotImplementedError, "Subclass must implement #agent_role"
    end

    # Subclass contract: default threshold
    #
    # @return [Integer]
    def default_threshold
      raise NotImplementedError, "Subclass must implement #default_threshold"
    end

    # Subclass contract: gate context for PromptBuilder
    #
    # @return [Hash]
    def gate_context
      {
        prd_content: @execution.project.prd_content,
        acceptance_criteria: @execution.project.acceptance_criteria,
        task_results: build_task_results,
        previous_feedback: build_previous_feedback
      }
    end

    private

    # Build prompt using PromptBuilder
    def build_prompt
      @prompt = PromptBuilder.build(
        phase: prompt_template_phase,
        context: gate_context
      )
    end

    # Dispatch agent using DispatchService
    def dispatch_agent
      @dispatch_result = DispatchService.call(
        team_name: @execution.team.name,
        agent_identifier: agent_role,
        prompt: @prompt,
        project_path: @execution.project.path
      )
    end

    # Parse score using ScoreParser
    def parse_score(text = nil)
      @parsed_score = ScoreParser.call(
        text: text || @dispatch_result&.result || ""
      )
    end

    # Create artifact for the gate evaluation
    def create_artifact
      @artifact = create_artifact_record(
        score: @parsed_score.score,
        message: @parsed_score.feedback,
        dispatch_result: @dispatch_result
      )
    end

    # Build GateResult
    def build_result(threshold)
      GateResult.new(
        passed: @parsed_score.score >= (threshold || default_threshold),
        score: @parsed_score.score,
        feedback: @parsed_score.feedback,
        artifact: @artifact
      )
    end

    # Handle errors during evaluation
    def handle_error(error)
      error_artifact = create_error_artifact(error)
      GateResult.new(
        passed: false,
        score: 0,
        feedback: "Gate evaluation failed: #{error.message}",
        artifact: error_artifact
      )
    end

    # Build task results for context
    def build_task_results
      if @workflow_run
        @workflow_run.tasks.map do |task|
          {
            position: task.position,
            prompt: task.prompt,
            status: task.status,
            result: task.result,
            error_message: task.error_message
          }
        end
      else
        @execution.tasks.map do |task|
          {
            position: task.position,
            prompt: task.prompt,
            status: task.status,
            result: task.result,
            error_message: task.error_message
          }
        end
      end
    end

    # Build previous feedback for context
    def build_previous_feedback
      # Override in subclasses to include previous gate feedback
      ""
    end

    # Create artifact record (to be overridden by subclasses)
    def create_artifact_record(score:, message:, dispatch_result:)
      raise NotImplementedError, "Subclass must implement #create_artifact_record"
    end

    # Create error artifact record
    def create_error_artifact(error)
      raise NotImplementedError, "Subclass must implement #create_error_artifact"
    end
  end
end
