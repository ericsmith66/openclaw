# frozen_string_literal: true

module Legion
  class PlanExecutionService
    Result = Struct.new(
      :completed_count, :failed_count, :skipped_count, :total_count,
      :duration_ms, :halted, :halt_reason,
      keyword_init: true
    )

    WorkflowRunNotFoundError = Class.new(StandardError)
    NoTasksFoundError = Class.new(StandardError)
    StartFromTaskNotFoundError = Class.new(StandardError)
    DeadlockError = Class.new(StandardError)

    def self.call(workflow_run:, start_from: nil, continue_on_failure: false,
                  interactive: false, verbose: false, max_iterations: nil, dry_run: false)
      new(
        workflow_run: workflow_run,
        start_from: start_from,
        continue_on_failure: continue_on_failure,
        interactive: interactive,
        verbose: verbose,
        max_iterations: max_iterations,
        dry_run: dry_run
      ).call
    end

    def initialize(workflow_run:, start_from:, continue_on_failure:, interactive:,
                   verbose:, max_iterations:, dry_run:)
      @workflow_run = workflow_run
      @start_from = start_from
      @continue_on_failure = continue_on_failure
      @interactive = interactive
      @verbose = verbose
      @max_iterations = max_iterations
      @dry_run = dry_run
      @interrupted = false
    end

    def call
      run = find_workflow_run
      tasks = load_tasks(run)

      validate_start_from!(tasks) if @start_from

      # Dry-run: show execution waves without dispatching
      if @dry_run
        waves = compute_waves(tasks)
        print_dry_run(run, waves)
        return Result.new(
          completed_count: 0, failed_count: 0, skipped_count: 0,
          total_count: tasks.size, duration_ms: 0, halted: false, halt_reason: nil
        )
      end

      # Check if all tasks already in terminal state
      if all_terminal?(tasks)
        completed = tasks.count { |t| t.completed? }
        failed    = tasks.count { |t| t.failed? }
        skipped   = tasks.count { |t| t.skipped? }
        puts "All tasks already completed (#{completed} completed, #{failed} failed, #{skipped} skipped)"
        return Result.new(
          completed_count: completed, failed_count: failed, skipped_count: skipped,
          total_count: tasks.size, duration_ms: 0, halted: false, halt_reason: nil
        )
      end

      # Apply start_from — skip tasks before the given task
      apply_start_from!(tasks) if @start_from

      # Register SIGINT handler
      trap("INT") { @interrupted = true }

      @plan_start_time = Time.current
      dispatched_index = 0
      halted = false
      halt_reason = nil
      @total_tokens = 0

      print_header(run, tasks.size)

      loop do
        # Reload tasks to get fresh status from DB
        tasks = load_tasks(run)

        ready = ready_tasks(tasks)
        incomplete = all_incomplete(tasks)

        # Check for completion
        break if incomplete.empty?

        # Check for interrupt
        if @interrupted
          halted = true
          halt_reason = "interrupted"
          break
        end

        # Deadlock detection
        if ready.empty? && incomplete.any?
          stuck_info = incomplete.map do |t|
            missing_deps = t.dependencies.reject(&:completed?).map(&:id)
            "  Task ##{t.id}: deps #{missing_deps.inspect}"
          end.join("\n")
          raise DeadlockError, "Deadlock: #{incomplete.size} tasks have unsatisfied dependencies\n#{stuck_info}"
        end

        task = ready.first
        dispatched_index += 1
        @task_start_time = Time.current

        print_task_start(dispatched_index, tasks.size, task)

        # Mark task as running
        task.with_lock { task.update!(status: :running) }

        begin
          execution_run = dispatch_task(task, run.project.path)

          # Set reverse link: execution WorkflowRun → task that triggered it
          execution_run.update!(task: task) if execution_run.task_id.nil?

          task.with_lock do
            task.update!(status: :completed, execution_run: execution_run)
          end

          print_task_result(task, execution_run, dispatched_index, tasks.size)
        rescue StandardError => e
          # Attempt to get execution_run from the error context if available
          execution_run = nil
          task_duration = format_duration(((Time.current - @task_start_time) * 1000).to_i)

          task.with_lock do
            task.update!(
              status: :failed,
              metadata: task.metadata.merge("error_message" => e.message)
            )
          end

          puts "  └─ ❌ Failed after #{task_duration} — #{e.message}"
          puts

          if @continue_on_failure
            mark_dependents_skipped(task, tasks)
          else
            halted = true
            halt_reason = "Task ##{task.id} failed: #{e.message}"
            break
          end
        end
      end

      duration_ms = ((Time.current - @plan_start_time) * 1000).to_i

      # Reload for final counts
      tasks = load_tasks(run)
      completed_count = tasks.count(&:completed?)
      failed_count    = tasks.count(&:failed?)
      skipped_count   = tasks.count(&:skipped?)

      result = Result.new(
        completed_count: completed_count,
        failed_count: failed_count,
        skipped_count: skipped_count,
        total_count: tasks.size,
        duration_ms: duration_ms,
        halted: halted,
        halt_reason: halt_reason
      )

      print_summary(result, run)

      if halted && halt_reason == "interrupted"
        raise Interrupt
      end

      result
    end

    private

    def find_workflow_run
      return @workflow_run if @workflow_run.is_a?(WorkflowRun)

      run = WorkflowRun.find_by(id: @workflow_run)
      raise WorkflowRunNotFoundError, "WorkflowRun ##{@workflow_run} not found" unless run
      run
    end

    def load_tasks(run)
      tasks = Task.where(workflow_run: run)
                  .by_position
                  .includes(:dependencies, :dependents, :team_membership)
                  .to_a

      raise NoTasksFoundError, "No tasks found for WorkflowRun ##{run.id}" if tasks.empty?

      # Reset any :running tasks to :pending (from a previous interrupted run)
      tasks.each do |task|
        task.update!(status: :pending) if task.running?
      end

      tasks
    end

    def validate_start_from!(tasks)
      task_ids = tasks.map(&:id)
      unless task_ids.include?(@start_from.to_i)
        raise StartFromTaskNotFoundError, "Task ##{@start_from} not found in WorkflowRun"
      end
    end

    def apply_start_from!(tasks)
      start_id = @start_from.to_i
      start_task = tasks.find { |t| t.id == start_id }
      return unless start_task

      tasks.each do |task|
        if task.position < start_task.position
          task.update!(status: :skipped)
        end
      end
    end

    def ready_tasks(tasks)
      tasks.select do |task|
        next false unless task.pending? || task.ready?
        task.dependencies.all?(&:completed?)
      end
    end

    def all_incomplete(tasks)
      tasks.reject { |t| t.completed? || t.failed? || t.skipped? }
    end

    def all_terminal?(tasks)
      tasks.all? { |t| t.completed? || t.failed? || t.skipped? }
    end

    def dispatch_task(task, project_path)
      enriched_prompt = enrich_prompt_with_file_context(task.error_context_enriched_prompt, project_path)

      DispatchService.call(
        team_name: task.team_membership.agent_team.name,
        agent_identifier: task.team_membership.config["id"],
        prompt: enriched_prompt,
        project_path: project_path,
        max_iterations: @max_iterations,
        interactive: @interactive,
        verbose: @verbose
      )
    end

    # Scans the task prompt for file paths referenced in backticks (e.g. `lib/foo.rb`)
    # and appends their contents so the agent doesn't waste turns reading them.
    def enrich_prompt_with_file_context(prompt, project_path)
      # Extract backtick-quoted paths that look like source files
      file_refs = prompt.scan(/`([^`]+\.[a-z]{1,4})`/).flatten.uniq

      # Filter to files that actually exist, limit to 5 to avoid prompt bloat
      existing_files = file_refs.select do |ref|
        path = File.join(project_path, ref)
        File.exist?(path) && File.file?(path) && File.size(path) < 50_000
      end.first(5)

      return prompt if existing_files.empty?

      context_blocks = existing_files.map do |ref|
        path = File.join(project_path, ref)
        content = File.read(path)
        "### File: `#{ref}` (#{content.lines.count} lines)\n```\n#{content}\n```"
      end

      "#{prompt}\n\n---\n## Reference Files (pre-loaded — do NOT re-read these)\n\n#{context_blocks.join("\n\n")}"
    end

    def mark_dependents_skipped(failed_task, all_tasks)
      # BFS through transitive dependents
      queue = failed_task.dependents.to_a.dup
      visited = Set.new([ failed_task.id ])

      while queue.any?
        dep_task = queue.shift
        next if visited.include?(dep_task.id)
        visited << dep_task.id

        dep_task.update!(status: :skipped)

        # Find the full task record with dependents loaded
        full_task = all_tasks.find { |t| t.id == dep_task.id }
        queue.concat(full_task.dependents.to_a) if full_task
      end
    end

    def compute_waves(tasks)
      # Topological sort into waves using task dependency positions
      # Build dependency graph: task_id → [depends_on_task_id, ...]
      dep_map = {}
      tasks.each do |task|
        dep_map[task.id] = task.dependencies.map(&:id)
      end

      waves = []
      completed_ids = Set.new

      remaining = tasks.dup

      loop do
        ready = remaining.select do |task|
          dep_map[task.id].all? { |dep_id| completed_ids.include?(dep_id) }
        end
        break if ready.empty?

        waves << ready
        ready.each { |t| completed_ids << t.id }
        remaining -= ready
      end

      waves
    end

    def print_header(workflow_run, task_count)
      project_name = workflow_run.project.name rescue "unknown"
      puts "━" * 72
      puts "  Executing WorkflowRun ##{workflow_run.id} — #{project_name}"
      puts "  Tasks: #{task_count} | Mode: #{@continue_on_failure ? 'continue-on-failure' : 'halt-on-failure'}"
      puts "━" * 72
      puts
    end

    def print_task_start(index, total, task)
      agent_name = task.team_membership.config["name"] || "unknown"
      model_name = task.team_membership.config["model"] || "unknown"
      run_elapsed = format_duration(((Time.current - @plan_start_time) * 1000).to_i)

      dep_info = if task.dependencies.any?
        deps_str = task.dependencies.map { |d| "##{d.id} #{d.completed? ? '✅' : '⏳'}" }.join(", ")
        "\n  ├─ deps: #{deps_str}"
      else
        ""
      end

      puts "  [#{index}/#{total}] ▶ Task ##{task.id} — #{agent_name} (#{model_name})"
      puts "  ├─ #{task.prompt.truncate(80)}"
      puts "  ├─ run elapsed: #{run_elapsed}#{dep_info}"
    end

    def print_task_result(task, execution_run, _dispatched_index = nil, _total = nil)
      task_elapsed = format_duration(((Time.current - @task_start_time) * 1000).to_i)

      if execution_run
        turns = execution_run.workflow_events.where(event_type: "response.complete").count
        tokens = extract_token_counts(execution_run)
        @total_tokens += tokens[:total]

        stats = [ task_elapsed ]
        stats << "#{turns} turns" if turns > 0
        stats << format_token_summary(tokens) if tokens[:total] > 0

        puts "  └─ ✅ #{stats.join(' | ')}"
      else
        puts "  └─ ✅ #{task_elapsed}"
      end
      puts
    end

    def print_dry_run(workflow_run, waves)
      task_count = waves.sum(&:size)
      puts "Execution Plan for WorkflowRun ##{workflow_run.id} (#{task_count} tasks)"
      puts "━" * 44
      puts
      puts "Execution Order (sequential):"
      puts

      waves.each_with_index do |wave, idx|
        wave_num = idx + 1
        after_info = idx == 0 ? "" : " (after wave #{idx})"
        parallel_info = wave.size > 1 ? " (parallel-eligible)" : ""
        puts "Wave #{wave_num}#{parallel_info}#{after_info}:"

        wave.each do |task|
          profile_name = begin
            task.team_membership.to_profile.name
          rescue StandardError
            task.team_membership.config["name"] || "unknown"
          end

          dep_str = task.dependencies.any? ? " ← deps: [#{task.dependencies.map(&:id).join(',')}]" : ""
          puts "  Task #{task.id}: [#{task.task_type}] #{profile_name} — #{task.prompt.truncate(60)} (score #{task.total_score})#{dep_str}"
        end
        puts
      end

      puts "DRY RUN — no tasks executed"
    end

    def print_summary(result, run)
      puts "━" * 72

      total_tokens_str = format_tokens(@total_tokens)
      duration_str = format_duration(result.duration_ms)

      if result.halted
        case result.halt_reason
        when "interrupted"
          puts "  ⚠️  Plan interrupted after #{duration_str}"
          puts "  #{result.completed_count}/#{result.total_count} completed | " \
               "#{result.failed_count} failed | #{result.skipped_count} skipped"
        else
          puts "  ❌ Plan halted after #{duration_str}"
          puts "  #{result.completed_count}/#{result.total_count} completed | " \
               "#{result.failed_count} failed | #{result.skipped_count} skipped"
          puts "  Tokens used: #{total_tokens_str}" if @total_tokens > 0
          puts
          puts "  Hints:"
          puts "    --continue-on-failure  skip failed tasks and continue"
          puts "    --start-from #{failed_task_id(run)}         retry from the failed task" if failed_task_id(run)
        end
      elsif result.failed_count > 0
        puts "  ⚠️  Plan complete (with failures) — #{duration_str}"
        puts "  #{result.completed_count}/#{result.total_count} completed | " \
             "#{result.failed_count} failed | #{result.skipped_count} skipped"
        puts "  Tokens used: #{total_tokens_str}" if @total_tokens > 0
      else
        puts "  ✅ Plan complete — #{duration_str}"
        puts "  #{result.completed_count}/#{result.total_count} tasks succeeded | " \
             "Tokens: #{total_tokens_str}"
      end

      puts "━" * 72
    end

    def failed_task_id(run)
      Task.where(workflow_run: run, status: :failed).order(:position).pick(:id)
    end

    def extract_token_counts(execution_run)
      totals = { total: 0, prompt: 0, completion: 0 }

      execution_run.workflow_events
                   .where(event_type: "response.complete")
                   .pluck(:payload)
                   .each do |payload|
        usage = payload["usage"] || {}
        totals[:total]      += (usage["total_tokens"] || 0)
        totals[:prompt]     += (usage["prompt_tokens"] || 0)
        totals[:completion] += (usage["completion_tokens"] || 0)
      end

      totals
    rescue StandardError
      { total: 0, prompt: 0, completion: 0 }
    end

    def format_token_summary(tokens)
      "#{format_tokens(tokens[:total])} tokens (#{format_tokens(tokens[:prompt])}p/#{format_tokens(tokens[:completion])}c)"
    end

    def format_tokens(count)
      count ||= 0
      if count >= 1_000_000
        "#{(count / 1_000_000.0).round(1)}M"
      elsif count >= 1_000
        "#{(count / 1_000.0).round(1)}K"
      else
        count.to_s
      end
    end

    def format_duration(duration_ms)
      duration_ms ||= 0
      total_seconds = duration_ms / 1000
      minutes = total_seconds / 60
      seconds = total_seconds % 60
      minutes > 0 ? "#{minutes}m #{seconds}s" : "#{seconds}s"
    end
  end
end
