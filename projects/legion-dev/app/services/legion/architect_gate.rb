# frozen_string_literal: true

module Legion
  # QualityGate subclass for Architect review evaluations
  #
  # ArchitectGate evaluates architect review artifacts and determines if they
  # meet the quality threshold. It extends QualityGate with specific behavior
  # for architect review artifacts.
  #
  # @see QualityGate
  class ArchitectGate < QualityGate
    def gate_name; "architect"; end
    def prompt_template_phase; :architect_review; end
    def agent_role; "architect"; end
    def default_threshold; 80; end

    # Initialize with execution and optional workflow_run
    #
    # @param execution [WorkflowExecution] The workflow execution context
    # @param workflow_run [WorkflowRun, nil] Optional workflow run (for ArchitectGate)
    def initialize(execution:, workflow_run: nil)
      super
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
      "architect"
    end

    # Subclass contract: prompt template phase symbol
    #
    # @return [Symbol]
    def prompt_template_phase
      :architect_review
    end

    # Subclass contract: agent role identifier
    #
    # @return [String]
    def agent_role
      "architect"
    end

    # Subclass contract: default threshold
    #
    # @return [Integer]
    def default_threshold
      80
    end

    # Gate context for PromptBuilder
    #
    # @return [Hash]
    def gate_context
      {
        prd_content: @execution.project.prd_content,
        acceptance_criteria: @execution.project.acceptance_criteria,
        task_list: build_task_list,
        dag: build_dag,
        previous_feedback: build_previous_feedback
      }
    end

    private

    # Build task list for context
    def build_task_list
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

    # Build DAG (Directed Acyclic Graph) for context
    def build_dag
      if @workflow_run
        tasks = @workflow_run.tasks.includes(:task_dependencies)
      else
        tasks = @execution.tasks.includes(:task_dependencies)
      end

      tasks.map do |task|
        {
          position: task.position,
          prompt: task.prompt,
          dependencies: task.task_dependencies.map(&:depends_on_task_position)
        }
      end
    end

    # Build previous feedback for context
    def build_previous_feedback
      # Override in subclasses to include previous gate feedback
      ""
    end

    # Create artifact record for architect review
    def create_artifact_record(score:, message:, dispatch_result:)
      content = if score > 0
                  "## Score\n#{score}/100\n\n## Feedback\n#{message}"
      else
                  "## Score\n0/100\n\n## Feedback\nScore parsing failed — manual review required\n\nRaw Output:\n#{dispatch_result.result}"
      end

      workflow_run = @workflow_run || create_workflow_run

      workflow_run.artifacts.create!(
        artifact_type: :architect_review,
        name: "Architect Review #{workflow_run.artifacts.count + 1}",
        content: content,
        project_id: workflow_run.project_id,
        created_by: workflow_run.project.agent_teams.first,
        metadata: { score: score, parser_message: message }
      )
    end

    # Create error artifact record
    def create_error_artifact(error)
      workflow_run = @workflow_run || create_workflow_run

      workflow_run.artifacts.create!(
        artifact_type: :architect_review,
        name: "Architect Review (Error) #{workflow_run.artifacts.count + 1}",
        content: "Architect review failed: #{error.message}",
        project_id: workflow_run.project_id,
        created_by: workflow_run.project.agent_teams.first,
        metadata: { error: error.class.name, error_message: error.message }
      )
    end

    # Create workflow_run if it doesn't exist
    def create_workflow_run
      team_membership = @execution.project.agent_teams.first&.team_memberships&.first ||
                        @execution.project.agent_teams.first&.team_memberships&.create!(
                          position: 0,
                          config: {
                            "id" => "ror-rails-legion",
                            "name" => "Rails Lead (Legion)",
                            "provider" => "deepseek",
                            "model" => "deepseek-reasoner",
                            "reasoningEffort" => "none",
                            "maxIterations" => 200,
                            "maxTokens" => nil,
                            "temperature" => nil,
                            "minTimeBetweenToolCalls" => 0,
                            "enabledServers" => [],
                            "includeContextFiles" => false,
                            "includeRepoMap" => false,
                            "usePowerTools" => true,
                            "useAiderTools" => true,
                            "useTodoTools" => true,
                            "useMemoryTools" => true,
                            "useSkillsTools" => true,
                            "useSubagents" => true,
                            "useTaskTools" => false,
                            "toolApprovals" => { "power---bash" => "ask" },
                            "toolSettings" => {},
                            "customInstructions" => "ZERO THINKING OUT LOUD",
                            "compactionStrategy" => "tiered",
                            "contextWindow" => 128_000,
                            "costBudget" => 0.0,
                            "contextCompactingThreshold" => 0.7,
                            "subagent" => {
                              "enabled" => false,
                              "systemPrompt" => "",
                              "invocationMode" => "on_demand",
                              "color" => "#3368a8",
                              "description" => "",
                              "contextMemory" => "off"
                            }
                          }
                        )
      @execution.workflow_runs.create!(
        project: @execution.project,
        team_membership: team_membership,
        prompt: "Architect review",
        status: :queued
      )
    end

    QualityGate.register(ArchitectGate)
  end
end
