# frozen_string_literal: true

module Legion
  class TeamImportService
    Result = Struct.new(:project, :team, :memberships, :created, :updated, :skipped, :unchanged, :errors, keyword_init: true)

    class << self
      def call(aider_desk_path:, project_path:, team_name:, dry_run: false)
        new(aider_desk_path, project_path, team_name, dry_run).call
      end
    end

    def initialize(aider_desk_path, project_path, team_name, dry_run)
      @aider_desk_path = aider_desk_path
      @project_path = project_path
      @team_name = team_name
      @dry_run = dry_run
      @errors = []
    end

    def call
      validate_paths
      agents_dir = File.join(@aider_desk_path, "agents")
      raise ArgumentError, "No agents directory found at #{agents_dir}/" unless Dir.exist?(agents_dir)
      raise ArgumentError, "No agent directories found in #{agents_dir}" if Dir.glob("*", base: agents_dir).empty?

      order = load_order_json(agents_dir)
      agent_dirs = ordered_agent_dirs(agents_dir, order)

      valid_configs = []
      agent_dirs.each do |dir_name, position|
        config_path = File.join(agents_dir, dir_name, "config.json")
        if File.exist?(config_path)
          begin
            config = JSON.parse(File.read(config_path))
            if valid_config?(config)
              valid_configs << { dir_name: dir_name, config: config, position: position }
            else
              missing = required_keys - config.keys
              @errors << "Agent #{dir_name}: missing required fields: #{missing.join(', ')}"
            end
          rescue JSON::ParserError => e
            @errors << "Agent #{dir_name}: malformed config.json - #{e.message}"
          end
        else
          @errors << "Agent #{dir_name}: config.json not found"
        end
      end

      if @dry_run
        Result.new(
          project: nil,
          team: nil,
          memberships: valid_configs.map { |c| { config: c[:config], status: "created" } },
          created: valid_configs.size,
          updated: 0,
          skipped: @errors.size,
          unchanged: 0,
          errors: @errors
        )
      else
        persist(valid_configs)
      end
    end

    private

    def validate_paths
      raise ArgumentError, "Directory not found: #{@aider_desk_path}" unless Dir.exist?(@aider_desk_path)
    end

    def load_order_json(agents_dir)
      order_path = File.join(agents_dir, "order.json")
      if File.exist?(order_path)
        begin
          JSON.parse(File.read(order_path))
        rescue JSON::ParserError => e
          Rails.logger.warn("Malformed order.json: #{e.message}, falling back to alphabetical")
          nil
        end
      else
        Rails.logger.warn("order.json not found, falling back to alphabetical")
        nil
      end
    end

    def ordered_agent_dirs(agents_dir, order)
      dirs = Dir.glob("*", base: agents_dir).select { |d| Dir.exist?(File.join(agents_dir, d)) }
      if order.is_a?(Hash)
        # Only include order.json entries whose directories actually exist on disk
        # (silently skip non-existent entries — they may be UUIDs for deleted agents)
        ordered = order.sort_by { |_, v| v }
                       .select { |k, _| dirs.include?(k) }
                       .map { |k, v| [ k, v ] }
        # Append dirs on disk that are not listed in order.json
        max_pos = ordered.map { |_, v| v }.max || -1
        dirs.each do |d|
          next if order.key?(d)
          max_pos += 1
          ordered << [ d, max_pos ]
          Rails.logger.warn("Agent #{d} not in order.json, appending at position #{max_pos}")
        end
        ordered
      else
        dirs.sort.map.with_index { |d, i| [ d, i ] }
      end
    end

    def valid_config?(config)
      required_keys.all? { |k| config.key?(k) }
    end

    def required_keys
      %w[id name provider model]
    end

    def persist(valid_configs)
      created = 0
      updated = 0
      unchanged = 0
      memberships = []
      project = nil
      team = nil

      ApplicationRecord.transaction do
        project = Project.find_or_initialize_by(path: @project_path)
        if project.new_record?
          project.name = File.basename(@project_path)
          project.save!
        end

        team = AgentTeam.find_or_initialize_by(name: @team_name, project: project)
        team.save! if team.new_record?

        valid_configs.each do |agent|
          membership = TeamMembership.where(agent_team: team).where("config->>'id' = ?", agent[:config]["id"]).first
          if membership
            if membership.config == agent[:config]
              unchanged += 1
              status = "unchanged"
            else
              membership.config = agent[:config]
              membership.position = agent[:position]
              membership.save!
              updated += 1
              status = "updated"
            end
          else
            membership = TeamMembership.create!(
              agent_team: team,
              config: agent[:config],
              position: agent[:position]
            )
            created += 1
            status = "created"
          end
          memberships << { membership: membership, status: status }
        end
      end

      Result.new(
        project: project,
        team: team,
        memberships: memberships,
        created: created,
        updated: updated,
        skipped: @errors.size,
        unchanged: unchanged,
        errors: @errors
      )
    end
  end
end
