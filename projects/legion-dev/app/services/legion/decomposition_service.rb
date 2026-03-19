# frozen_string_literal: true

module Legion
  class DecompositionService
    Result = Struct.new(:workflow_run, :tasks, :warnings, :errors, :parallel_groups, keyword_init: true)

    PrdNotFoundError = Class.new(StandardError)
    EmptyPrdError = Class.new(StandardError)
    ParseError = Class.new(StandardError)

    def self.call(team_name:, prd_path:, agent_identifier: "architect", project_path:, dry_run: false, verbose: false)
      new(
        team_name: team_name,
        prd_path: prd_path,
        agent_identifier: agent_identifier,
        project_path: project_path,
        dry_run: dry_run,
        verbose: verbose
      ).call
    end

    def initialize(team_name:, prd_path:, agent_identifier:, project_path:, dry_run:, verbose:)
      @team_name = team_name
      @prd_path = prd_path
      @agent_identifier = agent_identifier
      @project_path = project_path
      @dry_run = dry_run
      @verbose = verbose
    end

    def call
      prd_content = read_prd_content
      prompt = build_decomposition_prompt(prd_content)

      # Dispatch Architect agent
      workflow_run = dispatch_architect(prompt)

      # Update status to decomposing (after agent run completes)
      workflow_run.update!(status: :decomposing)

      # Print verbose output if requested
      print_verbose_response(workflow_run.result) if @verbose

      # Parse response
      parse_result = DecompositionParser.call(response_text: workflow_run.result)

      # Check for errors
      if parse_result.errors.any?
        workflow_run.update!(status: :failed, error_message: parse_result.errors.join("; "))
        raise ParseError, "Failed to parse decomposition: #{parse_result.errors.join('; ')}"
      end

      # Save tasks unless dry-run
      unless @dry_run
        save_tasks(workflow_run, parse_result.tasks)
      end

      # Detect parallel groups
      parallel_groups = detect_parallel_groups(parse_result.tasks)

      # Print output
      print_output(parse_result.tasks, parse_result.warnings, parallel_groups, workflow_run)

      # Update workflow_run to completed
      workflow_run.update!(status: :completed)

      # Fire event callback for task orchestration
      fire_decomposition_complete_callback(workflow_run)

      Result.new(
        workflow_run: workflow_run,
        tasks: parse_result.tasks,
        warnings: parse_result.warnings,
        errors: parse_result.errors,
        parallel_groups: parallel_groups
      )
    end

    private

    def read_prd_content
      unless File.exist?(@prd_path)
        raise PrdNotFoundError, "File not found: #{@prd_path}"
      end

      content = File.read(@prd_path)

      if content.strip.empty?
        raise EmptyPrdError, "PRD file is empty"
      end

      content
    end

    def build_decomposition_prompt(prd_content)
      PromptBuilder.build(
        phase: :decompose,
        context: {
          prd_content: prd_content,
          project_path: @project_path
        }
      )
    end

    def dispatch_architect(prompt)
      DispatchService.call(
        team_name: @team_name,
        agent_identifier: @agent_identifier,
        prompt: prompt,
        project_path: @project_path,
        interactive: false,
        verbose: false
      )
    end

    def print_verbose_response(response)
      puts "━━━ Architect Response ━━━"
      puts response
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    end

    def save_tasks(workflow_run, tasks)
      project = workflow_run.project

      # TODO: PRD-1-06 --force flag for partial saves (deferred)
      # If --force is enabled and some tasks have validation errors,
      # save valid tasks only and report which tasks were skipped.

      # Find team for agent mapping
      team = AgentTeam.find_by(project: project, name: @team_name)

      ApplicationRecord.transaction do
        # Phase 1: Create all Task records
        task_map = {}

        tasks.each do |task_data|
          # Map agent identifier to TeamMembership
          membership = find_team_membership(team, task_data[:agent])

          task = Task.create!(
            project: project,
            workflow_run: workflow_run,
            team_membership: membership,
            prompt: task_data[:prompt],
            task_type: task_data[:type],
            status: :pending,
            position: task_data[:position],
            files_score: task_data[:files_score],
            concepts_score: task_data[:concepts_score],
            dependencies_score: task_data[:dependencies_score],
            total_score: task_data[:total_score]
          )

          task_map[task_data[:position]] = task
        end

        # Phase 2: Create all TaskDependency records
        tasks.each do |task_data|
          task_data[:depends_on].each do |dep_position|
            TaskDependency.create!(
              task: task_map[task_data[:position]],
              depends_on_task: task_map[dep_position]
            )
          end
        end
      end
    end

    def find_team_membership(team, agent_identifier)
      membership = team.team_memberships.by_identifier(agent_identifier).first

      unless membership
        # Default to first available agent with warning
        membership = team.team_memberships.ordered.first
        warn "WARNING: Agent '#{agent_identifier}' not found in team. Defaulting to #{membership.config['name']}"
      end

      membership
    end

    def detect_parallel_groups(tasks)
      # Group tasks by dependency state
      # Group 1: Tasks with no dependencies (parallel-eligible)
      # Group N: Tasks where all dependencies are in previous groups

      groups = []
      remaining = tasks.dup
      completed_positions = []

      loop do
        # Find tasks where all dependencies are completed
        ready = remaining.select do |task|
          task[:depends_on].all? { |dep| completed_positions.include?(dep) }
        end

        break if ready.empty?

        groups << ready.map { |t| t[:position] }
        completed_positions.concat(ready.map { |t| t[:position] })
        remaining -= ready
      end

      groups
    end

    def print_output(tasks, warnings, parallel_groups, workflow_run = nil)
      puts "\nDecomposing: #{File.basename(@prd_path)}"
      puts "Agent: #{@agent_identifier}"
      puts "WorkflowRun: ##{workflow_run.id}" if workflow_run
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts

      # Print task table
      print_task_table(tasks)

      # Print parallel groups
      print_parallel_groups(parallel_groups)

      # Print warnings
      if warnings.any?
        puts "\n⚠️  Warnings:"
        warnings.each { |w| puts "  • #{w}" }
      end

      # Print dry-run notice
      if @dry_run
        puts "\nDRY RUN — no records saved"
      else
        puts "\nSaved #{tasks.size} tasks with #{count_dependencies(tasks)} dependency edges"
        puts "Run: bin/legion execute-plan --workflow-run #{workflow_run.id}" if workflow_run
      end
    end

    def print_task_table(tasks)
      # Header
      puts format("%-4s %-6s %-12s %-9s %-8s %-10s %s",
                  "#", "Type", "Agent", "Score", "Deps", "Status", "Prompt")
      puts "─" * 100

      # Rows
      tasks.each do |task|
        deps_str = task[:depends_on].empty? ? "—" : "[#{task[:depends_on].join(',')}]"
        score_str = "#{task[:files_score]}+#{task[:concepts_score]}+#{task[:dependencies_score]}=#{task[:total_score]}"
        prompt_preview = task[:prompt].length > 50 ? "#{task[:prompt][0..47]}..." : task[:prompt]

        puts format("%-4s %-6s %-12s %-9s %-8s %-10s %s",
                    task[:position],
                    task[:type],
                    task[:agent],
                    score_str,
                    deps_str,
                    "pending",
                    prompt_preview)
      end
    end

    def print_parallel_groups(groups)
      return if groups.empty?

      puts "\nParallel groups:"
      groups.each_with_index do |group, index|
        puts "  • Group #{index + 1}: Tasks #{group.join(', ')} #{index == 0 ? '(independent)' : ''}"
      end
    end

    def count_dependencies(tasks)
      tasks.sum { |t| t[:depends_on].size }
    end

    # FR-8: Event callback for decomposition completion
    def fire_decomposition_complete_callback(workflow_run)
      return if @dry_run

      Rails.logger.info("[DecompositionService] Decomposition complete for WorkflowRun ##{workflow_run.id}")

      # Enqueue ConductorJob for orchestrating next steps
      ConductorJob.perform_later(
        workflow_run_id: workflow_run.id,
        trigger: :decomposition_complete
      )
    end
  end
end
