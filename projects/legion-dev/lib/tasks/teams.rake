# frozen_string_literal: true

namespace :teams do
  desc "Import agent team from .aider-desk directory"
  task :import, [ :aider_desk_path ] => :environment do |_t, args|
    raw_path = ENV.fetch("PROJECT_PATH", nil)
    project_path = raw_path ? File.expand_path(raw_path) : Rails.root.to_s
    team_name = ENV.fetch("TEAM_NAME", "Default")
    dry_run = ENV.key?("DRY_RUN")
    aider_desk_path = args[:aider_desk_path] || default_aider_desk_path(project_path)

    result = Legion::TeamImportService.call(
      aider_desk_path: aider_desk_path,
      project_path: project_path,
      team_name: team_name,
      dry_run: dry_run
    )

    print_summary(result, aider_desk_path, project_path, team_name, dry_run)

    exit(1) if result.errors.any?
  end

  private

  def default_aider_desk_path(project_path)
    project_aider_desk = File.join(project_path, ".aider-desk")
    Dir.exist?(project_aider_desk) ? project_aider_desk : File.expand_path("~/.aider-desk")
  end

  def print_summary(result, aider_desk_path, project_path, team_name, dry_run)
    puts "Importing agents from #{aider_desk_path}"
    puts "Project: #{result.project&.name || 'N/A'} (#{project_path})"
    puts "Team: #{result.team&.name || team_name}"
    puts

    if dry_run
      puts "DRY RUN - Would import #{result.created} agents"
      puts "Would create: #{result.created}, update: #{result.updated}, skip: #{result.skipped}"
    else
      puts "  #  Agent                     Provider   Model               Status"
      result.memberships.each do |item|
        m = item[:membership]
        status = item[:status]
        puts format("  %-2d %-24s %-9s %-18s %s",
                    m.position + 1,
                    m.config["name"][0..23],
                    m.config["provider"][0..8],
                    m.config["model"][0..17],
                    status)
      end
      puts
      puts "Imported #{result.memberships.size} agents (#{result.created} created, #{result.updated} updated, #{result.unchanged} unchanged, #{result.skipped} skipped)"
    end

    if result.errors.any?
      puts
      puts "Errors:"
      result.errors.each { |e| puts "  - #{e}" }
    end
  end
end
