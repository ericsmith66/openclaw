# frozen_string_literal: true

module Legion
  # Service to initialize a new workflow execution, acquire project-level locks,
  # and enqueue the first ConductorJob to begin orchestration.
  #
  # This service handles FR-1: Workflow Execution Initialization.
  #
  # @see PRD-2-01: Workflow Execution Initialization
  # @see Legion::AdvisoryLockService for project-level locking
  # @see ConductorNotConfiguredError when conductor team is missing
  class WorkflowEngine
    class << self
      # Main entry point for creating a new workflow execution.
      #
      # @param prd_path [String] path to the PRD file
      # @param project [Project, Integer] project object or project_id
      # @param team [AgentTeam, Integer] team object or team_id
      # @param options [Hash] optional configuration
      # @option options [Boolean] :dry_run if true, no execution occurs
      # @option options [Boolean] :verbose if true, enable verbose logging
      # @option options [Boolean] :skip_scoring if true, bypass ConductorJob and execute services directly
      # @return [WorkflowExecution] created workflow execution record
      # @raise [WorkflowLockError] if advisory lock cannot be acquired
      # @raise [ConductorNotConfiguredError] if conductor team not found
      def call(prd_path:, project:, team:, **options)
        new(prd_path: prd_path, project: project, team: team, **options).call
      end
    end

    # @param prd_path [String] path to the PRD file
    # @param project [Project, Integer] project object or project_id
    # @param team [AgentTeam, Integer] team object or team_id
    # @param options [Hash] optional configuration
    def initialize(prd_path:, project:, team:, **options)
      @prd_path = prd_path
      @project = project.is_a?(Project) ? project : Project.find(project)
      @team = team.is_a?(AgentTeam) ? team : AgentTeam.find(team)
      @options = options
    end

    # Execute the workflow engine service.
    #
    # @return [WorkflowExecution] created workflow execution record
    # @raise [WorkflowLockError] if advisory lock cannot be acquired
    # @raise [ConductorNotConfiguredError] if conductor team not found
    def call
      ensure_conductor_team_exists
      if options[:skip_scoring]
        execute_skip_scoring_workflow
      else
        acquire_lock_and_create_execution
      end
    end

    private

    attr_reader :prd_path, :project, :team, :options

    # Verify that the conductor team exists and is properly configured.
    #
    # @raise [ConductorNotConfiguredError] if conductor team not found
    def ensure_conductor_team_exists
      conductor_team = AgentTeam.find_by(project: project, name: "conductor")
      raise ConductorNotConfiguredError, "Conductor team not configured for project #{project.id}" unless conductor_team
    end

    # Acquire advisory lock and create workflow execution within transaction.
    #
    # @return [WorkflowExecution] created workflow execution record
    # @raise [WorkflowLockError] if advisory lock cannot be acquired
    def acquire_lock_and_create_execution
      lock_result = AdvisoryLockService.acquire_lock(project_id: project.id)

      unless lock_result&.acquired
        raise WorkflowLockError.new(
          "Could not acquire lock for project #{project.id}",
          lock_result&.lock_key || AdvisoryLockService.lock_key(project.id)
        )
      end

      begin
        execution = create_execution
        enqueue_first_conductor_job(execution)
        execution
      ensure
        AdvisoryLockService.release_lock(project_id: project.id)
      end
    end

    # Execute workflow in skip-scoring mode (direct service calls without Conductor).
    #
    # This method implements D-40 and FR-2 requirements:
    # - Bypasses ConductorJob entirely
    # - Calls DecompositionService directly
    # - Calls PlanExecutionService after decomposition
    # - Sets status to completed when all tasks finish
    # - Skips gates, retry, and retrospective
    #
    # @return [WorkflowExecution] created workflow execution record
    def execute_skip_scoring_workflow
      # Create execution without lock (no concurrency control in skip-scoring mode)
      execution = create_execution

      # Call DecompositionService directly
      decomposition_result = call_decomposition_service

      # Call PlanExecutionService after decomposition
      if decomposition_result&.workflow_run
        call_plan_execution_service(decomposition_result.workflow_run)
      end

      # In skip-scoring mode, set status to completed after all tasks finish
      # (no gates, retry, or retrospective)
      execution.update!(status: :completed) if execution

      execution
    end

    # Create a new WorkflowExecution record.
    #
    # @return [WorkflowExecution] created workflow execution record
    def create_execution
      prd_content = File.read(prd_path)
      content_hash = Digest::SHA256.hexdigest(prd_content)

      WorkflowExecution.create!(
        project: project,
        prd_path: prd_path,
        prd_snapshot: prd_content,
        prd_content_hash: content_hash,
        phase: :planning,
        concurrency: 3,
        task_retry_limit: 3
      )
    end

    # Call DecompositionService with appropriate options.
    #
    # @return [DecompositionService::Result] result from decomposition service
    def call_decomposition_service
      DecompositionService.call(
        team_name: team.name,
        prd_path: prd_path,
        agent_identifier: "architect",
        project_path: project.path,
        dry_run: options[:dry_run] || false,
        verbose: options[:verbose] || false
      )
    end

    # Call PlanExecutionService with appropriate options.
    #
    # @param workflow_run [WorkflowRun] workflow run from decomposition
    # @return [PlanExecutionService::Result] result from plan execution service
    def call_plan_execution_service(workflow_run)
      PlanExecutionService.call(
        workflow_run: workflow_run,
        start_from: options[:start_from],
        continue_on_failure: options[:continue_on_failure] || false,
        interactive: options[:interactive] || false,
        verbose: options[:verbose] || false,
        max_iterations: options[:max_iterations],
        dry_run: options[:dry_run] || false
      )
    end

    # Enqueue the first ConductorJob to begin orchestration.
    #
    # @param execution [WorkflowExecution] created workflow execution record
    def enqueue_first_conductor_job(execution)
      ConductorJob.perform_later(
        execution_id: execution.id,
        trigger: :start
      )
    end
  end

  # Error raised when conductor team is not configured for a project
  class ConductorNotConfiguredError < StandardError; end
end
