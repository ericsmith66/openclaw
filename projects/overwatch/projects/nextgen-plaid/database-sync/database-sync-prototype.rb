#!/usr/bin/env ruby
# Database Sync Prototype
# Purpose: Demonstrate SSH-based database synchronization from remote server to local
# This is a prototype for review - not production ready

require 'open3'
require 'fileutils'
require 'time'
require 'logger'

class DatabaseSyncPrototype
  # Configuration with defaults
  CONFIG = {
    remote_host: '192.168.4.253',
    remote_user: ENV['USER'],
    ssh_port: '22',
    # PostgreSQL paths (Homebrew installation)
    remote_psql_path: '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql',
    remote_pg_dump_path: '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump',
    local_psql_path: '/opt/homebrew/opt/postgresql@16/bin/psql',
    local_pg_restore_path: '/opt/homebrew/opt/postgresql@16/bin/pg_restore',
    # Databases to sync
    databases: [
      { remote: 'nextgen_plaid_development', local: 'nextgen_plaid_development' },
      { remote: 'nextgen_plaid_development_queue', local: 'nextgen_plaid_development_queue' },
      { remote: 'nextgen_plaid_development_cable', local: 'nextgen_plaid_development_cable' }
    ],
    backup_dir: './tmp/db_backups',
    log_dir: './log'
  }.freeze

  attr_reader :config

  def initialize(options = {})
    @config = CONFIG.merge(options)
    @dry_run = options[:dry_run] || false
    @backup_existing = options[:backup_existing] || true
    @logger = Logger.new(STDOUT)
    setup_directories
  end

  def setup_directories
    FileUtils.mkdir_p(@config[:backup_dir])
    FileUtils.mkdir_p(@config[:log_dir])
  end

  def run_command(cmd, description)
    puts "[#{Time.now}] #{description}"
    puts "  Command: #{cmd}" if @dry_run

    return if @dry_run

    stdout, stderr, status = Open3.capture3(cmd)

    if status.success?
      puts "  ✓ Success"
      stdout.strip
    else
      puts "  ✗ Failed: #{stderr.strip}"
      nil
    end
  end

  def test_ssh_connection
    cmd = "ssh -p #{@config[:ssh_port]} #{@config[:remote_user]}@#{@config[:remote_host]} 'echo SSH connection successful'"
    run_command(cmd, "Testing SSH connection to #{@config[:remote_host]}")
  end

  def test_postgres_connection(host_type, psql_path)
    if host_type == :remote
      cmd = "ssh -p #{@config[:ssh_port]} #{@config[:remote_user]}@#{@config[:remote_host]} '#{psql_path} -c \"SELECT version();\"'"
    else
      cmd = "#{psql_path} -c \"SELECT version();\""
    end

    run_command(cmd, "Testing PostgreSQL connection (#{host_type})")
  end

  def backup_local_database(db_name)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_file = "#{@config[:backup_dir]}/#{db_name}_#{timestamp}.dump"

    cmd = "#{@config[:local_pg_restore_path].sub('pg_restore', 'pg_dump')} --format=custom --no-owner --no-acl -d #{db_name} -f #{backup_file}"

    if run_command(cmd, "Backing up local database #{db_name}")
      puts "  Backup saved to: #{backup_file}"
      backup_file
    else
      nil
    end
  end

  def drop_local_database(db_name)
    # First disconnect any existing connections
    terminate_cmd = "#{@config[:local_psql_path]} -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{db_name}' AND pid <> pg_backend_pid();\" postgres"
    run_command(terminate_cmd, "Terminating connections to #{db_name}")

    # Drop database
    drop_cmd = "#{@config[:local_psql_path]} -c \"DROP DATABASE IF EXISTS #{db_name};\" postgres"
    run_command(drop_cmd, "Dropping database #{db_name}")
  end

  def create_local_database(db_name)
    cmd = "#{@config[:local_psql_path]} -c \"CREATE DATABASE #{db_name};\" postgres"
    run_command(cmd, "Creating database #{db_name}")
  end

  def dump_remote_database(remote_db_name)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    dump_file = "#{@config[:backup_dir]}/#{remote_db_name}_remote_#{timestamp}.dump"

    # Use SSH to run pg_dump on remote and save locally
    cmd = "ssh -p #{@config[:ssh_port]} #{@config[:remote_user]}@#{@config[:remote_host]} '#{@config[:remote_pg_dump_path]} --format=custom --no-owner --no-acl #{remote_db_name}' > #{dump_file}"

    if run_command(cmd, "Dumping remote database #{remote_db_name}")
      # Check if dump file has content
      if File.exist?(dump_file) && File.size(dump_file) > 0
        puts "  Dump saved to: #{dump_file} (#{File.size(dump_file)} bytes)"
        dump_file
      else
        puts "  Warning: Dump file is empty or missing"
        nil
      end
    else
      nil
    end
  end

  def restore_local_database(dump_file, local_db_name)
    cmd = "#{@config[:local_pg_restore_path]} --no-owner --no-acl --clean --if-exists -d #{local_db_name} #{dump_file}"
    run_command(cmd, "Restoring to local database #{local_db_name}")
  end

  def sync_database(remote_db_name, local_db_name)
    puts "\n" + "="*60
    puts "Syncing #{remote_db_name} → #{local_db_name}"
    puts "="*60

    # Step 1: Backup existing local database
    if @backup_existing
      backup_local_database(local_db_name)
    end

    # Step 2: Dump remote database
    dump_file = dump_remote_database(remote_db_name)
    return unless dump_file

    # Step 3: Drop and recreate local database
    drop_local_database(local_db_name)
    create_local_database(local_db_name)

    # Step 4: Restore from dump
    restore_local_database(dump_file, local_db_name)

    # Step 5: Verify restoration
    verify_database(local_db_name)

    puts "✓ Sync completed for #{remote_db_name} → #{local_db_name}"
  end

  def verify_database(db_name)
    cmd = "#{@config[:local_psql_path]} -d #{db_name} -c \"SELECT COUNT(*) AS table_count FROM pg_tables WHERE schemaname = 'public';\""
    result = run_command(cmd, "Verifying database #{db_name}")
    puts "  Verification result: #{result}" if result
  end

  def sync_all
    puts "Starting database sync from #{@config[:remote_host]}"
    puts "Dry run: #{@dry_run}"
    puts "Backup existing: #{@backup_existing}"
    puts "-" * 60

    # Test connections
    unless test_ssh_connection
      puts "SSH connection failed. Aborting."
      return false
    end

    unless test_postgres_connection(:remote, @config[:remote_psql_path])
      puts "Remote PostgreSQL connection failed. Aborting."
      return false
    end

    unless test_postgres_connection(:local, @config[:local_psql_path])
      puts "Local PostgreSQL connection failed. Aborting."
      return false
    end

    # Sync each database
    @config[:databases].each do |db|
      sync_database(db[:remote], db[:local])
    end

    puts "\n" + "="*60
    puts "Database sync completed!"
    puts "="*60
    true
  end

  # Alternative: Stream directly without intermediate file (more efficient)
  def stream_sync_database(remote_db_name, local_db_name)
    puts "\nStream sync: #{remote_db_name} → #{local_db_name}"

    # Create pipeline: remote pg_dump -> local pg_restore
    ssh_cmd = "ssh -p #{@config[:ssh_port]} #{@config[:remote_user]}@#{@config[:remote_host]}"
    pg_dump_cmd = "#{@config[:remote_pg_dump_path]} --format=custom --no-owner --no-acl #{remote_db_name}"
    pg_restore_cmd = "#{@config[:local_pg_restore_path]} --no-owner --no-acl --clean --if-exists -d #{local_db_name}"

    full_cmd = "#{ssh_cmd} '#{pg_dump_cmd}' | #{pg_restore_cmd}"

    run_command(full_cmd, "Stream sync #{remote_db_name} → #{local_db_name}")
  end
end

# Command-line interface
if __FILE__ == $0
  require 'optparse'

  options = {
    dry_run: false,
    backup_existing: true,
    stream: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("--dry-run", "Show what would happen without executing") do
      options[:dry_run] = true
    end

    opts.on("--no-backup", "Skip backup of existing local databases") do
      options[:backup_existing] = false
    end

    opts.on("--stream", "Use streaming method (no intermediate files)") do
      options[:stream] = true
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  # Create sync instance
  sync = DatabaseSyncPrototype.new(options)

  # Run sync
  if options[:stream]
    puts "Using streaming method (prototype)"
    # For demo, just show the command
    sync.config[:databases].each do |db|
      ssh_cmd = "ssh -p #{sync.config[:ssh_port]} #{sync.config[:remote_user]}@#{sync.config[:remote_host]}"
      pg_dump_cmd = "#{sync.config[:remote_pg_dump_path]} --format=custom --no-owner --no-acl #{db[:remote]}"
      pg_restore_cmd = "#{sync.config[:local_pg_restore_path]} --no-owner --no-acl --clean --if-exists -d #{db[:local]}"
      puts "Command: #{ssh_cmd} '#{pg_dump_cmd}' | #{pg_restore_cmd}"
    end
  else
    sync.sync_all
  end
end
