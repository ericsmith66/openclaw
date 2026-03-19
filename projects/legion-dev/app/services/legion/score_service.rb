# frozen_string_literal: true

module Legion
  class ScoreService
    WorkflowRunNotFoundError = Class.new(StandardError)
    TeamNotFoundError = Class.new(StandardError)
    AgentNotFoundError = Class.new(StandardError)

    def self.call(workflow_run_id:, team_name:, threshold: 90, project_path:, agent_role: "qa")
      new(
        workflow_run_id: workflow_run_id,
        team_name: team_name,
        threshold: threshold,
        project_path: project_path,
        agent_role: agent_role
      ).call
    end

    def initialize(workflow_run_id:, team_name:, threshold: 90, project_path:, agent_role: "qa")
      @workflow_run_id = workflow_run_id
      @team_name = team_name
      @threshold = threshold
      @project_path = project_path
      @agent_role = agent_role
    end

    def call
      workflow_run = find_workflow_run
      team = find_team
      find_agent_membership(team)

      # Use QualityGate for evaluation (delegates to ScoreParser for parsing)
      quality_gate = QaGate.new(
        execution: workflow_run.workflow_execution,
        workflow_run: workflow_run
      )

      result = quality_gate.evaluate(threshold: @threshold)

      # Fire event callback for score completion
      fire_score_complete_callback(workflow_run, result.score)

      build_result(result.score, result.feedback, result.artifact)
    rescue WorkflowRunNotFoundError => e
      raise e
    rescue TeamNotFoundError => e
      raise e
    rescue AgentNotFoundError => e
      raise e
    rescue StandardError => e
      # For dispatch failures, create error artifact and return failed result
      error_artifact = create_error_artifact(workflow_run, e)
      Result.new(
        passed: false,
        score: 0,
        feedback: "Score evaluation failed: #{e.message}",
        artifact: error_artifact
      )
    end

    private

    def find_workflow_run
      workflow_run = WorkflowRun.find_by(id: @workflow_run_id)
      raise WorkflowRunNotFoundError, "WorkflowRun ##{@workflow_run_id} not found" unless workflow_run
      workflow_run
    end

    def find_team
      project = Project.find_by(path: @project_path)
      raise TeamNotFoundError, "Project not found at #{@project_path}" unless project

      team = AgentTeam.find_by(project: project, name: @team_name)
      raise TeamNotFoundError, "Team '#{@team_name}' not found" unless team
      team
    end

    def find_agent_membership(team)
      membership = team.team_memberships.find { |m| m.config["id"] == @agent_role }
      raise AgentNotFoundError, "No agent with role '#{@agent_role}' found in team '#{team.name}'" unless membership
      membership
    end

    def build_prompt(workflow_run)
      # Build prompt context from WorkflowRun data
      tasks_text = build_tasks_context(workflow_run)

      <<~PROMPT
        Please evaluate the workflow run output below and provide a score from 0 to 100.

        ## Context
        - Workflow Run: #{workflow_run.id}
        - Team: #{@team_name}

        ## Workflow Tasks and Results
        #{tasks_text}

        ## Instructions
        1. Analyze the workflow run's output
        2. Provide a score from 0 to 100
        3. Include specific feedback and issues

        ## Output Format
        ## Score
        <score>/100

        ## Feedback
        <detailed feedback>
      PROMPT
    end

    def build_tasks_context(workflow_run)
      if workflow_run.tasks.empty?
        "No tasks found in this workflow run."
      else
        workflow_run.tasks.map do |task|
          <<~TASK
            ### Task ##{task.position}: #{task.prompt.truncate(50)}
            Status: #{task.status}
            Result: #{task.result || "N/A"}
            #{task.error_message ? "Error: #{task.error_message}" : ""}
          TASK
        end.join("\n")
      end
    end

    def build_result(score, feedback, artifact)
      Result.new(
        passed: score >= @threshold,
        score: score,
        feedback: feedback || "",
        artifact: artifact
      )
    end

    # FR-8: Event callback for score completion
    def fire_score_complete_callback(workflow_run, score)
      Rails.logger.info("[ScoreService] Score evaluation complete for WorkflowRun ##{workflow_run.id}, score=#{score}")

      # Enqueue ConductorJob for orchestrating next steps
      ConductorJob.perform_later(
        workflow_run_id: workflow_run.id,
        trigger: :score_complete
      )
    end

    # Create error artifact for error handling
    def create_error_artifact(workflow_run, error)
      workflow_run.artifacts.create!(
        artifact_type: :score_report,
        name: "Score Report (Error) ##{workflow_run.artifacts.count + 1}",
        content: "Score evaluation failed: #{error.message}",
        project_id: workflow_run.project_id,
        created_by: workflow_run.project.agent_teams.first,
        metadata: { error: error.class.name, error_message: error.message }
      )
    end

    Result = Struct.new(:passed, :score, :feedback, :artifact, keyword_init: true)

    class ResultWrapper
      def initialize(result)
        @result = result
      end

      def result
        @result
      end
    end
  end
end
