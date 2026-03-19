# frozen_string_literal: true

module Legion
  class DispatchService
    TeamNotFoundError = Class.new(StandardError)
    AgentNotFoundError = Class.new(StandardError)

    def self.call(team_name:, agent_identifier:, prompt:, project_path:, max_iterations: nil, interactive: false, verbose: false)
      new(team_name:, agent_identifier:, prompt:, project_path:, max_iterations:, interactive:, verbose:).call
    end

    def initialize(team_name:, agent_identifier:, prompt:, project_path:, max_iterations:, interactive:, verbose:)
      @team_name = team_name
      @agent_identifier = agent_identifier
      @prompt = prompt
      @project_path = project_path
      @max_iterations = max_iterations
      @interactive = interactive
      @verbose = verbose
    end

    def call
      project = find_or_create_project
      team = find_team(project)
      membership = find_membership(team)

      workflow_run = create_workflow_run(project, membership)

      assembly_result = assemble_agent(membership, workflow_run)

      if @verbose
        subscribe_to_events(assembly_result[:message_bus])
      end

      execute_agent(assembly_result, workflow_run)

      print_summary(assembly_result[:profile], workflow_run)
    rescue Interrupt
      handle_error(workflow_run, Interrupt.new("interrupted by user"))
      raise
    rescue StandardError => e
      handle_error(workflow_run, e)
      raise
    end

    private

    def find_or_create_project
      Project.find_or_create_by!(path: @project_path) do |p|
        p.name = File.basename(@project_path).titleize
      end
    end

    def find_team(project)
      team = AgentTeam.find_by(project: project, name: @team_name)
      raise TeamNotFoundError, "Team '#{@team_name}' not found. Available teams: #{project.agent_teams.pluck(:name).join(', ')}" unless team
      team
    end

    def find_membership(team)
      membership = team.team_memberships.by_identifier(@agent_identifier).first
      unless membership
        available_agents = team.team_memberships.map { |m| m.config["name"] }.join(", ")
        raise AgentNotFoundError, "Agent '#{@agent_identifier}' not in team '#{@team_name}'. Available agents: #{available_agents}"
      end
      membership
    end

    def create_workflow_run(project, membership)
      WorkflowRun.create!(
        project: project,
        team_membership: membership,
        prompt: @prompt,
        status: :running
      )
    end

    def assemble_agent(membership, workflow_run)
      AgentAssemblyService.call(
        team_membership: membership,
        project_dir: @project_path,
        workflow_run: workflow_run,
        interactive: @interactive
      )
    end

    def subscribe_to_events(message_bus)
      message_bus.subscribe("*") do |channel, event|
        puts format_event(event)
      end
    end

    def format_event(event)
      case event.type
      when "agent.started"
        "[agent.started] #{event.agent_id} (#{event.payload['model']}) — starting"
      when "tool.called"
        "[tool.called] #{event.payload['tool_name']} → #{event.payload['status'] || 'called'}"
      when "tool.result"
        "[tool.result] #{event.payload['tool_name']} → #{event.payload['status'] || 'completed'}"
      when "response.complete"
        "[response.complete] #{event.payload['iterations']} iterations, #{event.payload['duration_ms']}ms"
      when "agent.completed"
        "[agent.completed] #{event.agent_id} — completed"
      else
        "[#{event.type}] #{event.payload.inspect}"
      end
    end

    def execute_agent(assembly_result, workflow_run)
      start_time = Time.current

      begin
        assembly_result[:runner].run(
          prompt: @prompt,
          system_prompt: assembly_result[:system_prompt],
          tool_set: assembly_result[:tool_set],
          profile: assembly_result[:profile],
          project_dir: @project_path,
          agent_id: assembly_result[:profile].id,
          task_id: nil,
          max_iterations: @max_iterations || assembly_result[:profile].max_iterations
        )

        duration_ms = ((Time.current - start_time) * 1000).to_i
        iterations = workflow_run.workflow_events.where(event_type: "response.complete").pluck(:payload).last&.dig("iterations") || 0
        result = workflow_run.workflow_events
                             .where(event_type: "response.chunk")
                             .order(:created_at)
                             .pluck(:payload)
                             .filter_map { |p| p["content"] }
                             .last || ""

        workflow_run.update!(
          status: :completed,
          duration_ms: duration_ms,
          iterations: iterations,
          result: result
        )
      rescue Interrupt
        raise
      rescue StandardError => e
        raise
      end
    end

    def print_summary(profile, workflow_run)
      puts "Agent: #{profile.name} (#{profile.provider}/#{profile.model})"
      puts "Status: #{workflow_run.status}"
      puts "Iterations: #{workflow_run.iterations}"
      puts "Duration: #{workflow_run.duration_ms}ms"
      puts "Events: #{workflow_run.workflow_events.count}"

      workflow_run
    end

    def handle_error(workflow_run, error)
      return unless workflow_run

      workflow_run.update!(
        status: :failed,
        error_message: error.message
      )
    end
  end
end
