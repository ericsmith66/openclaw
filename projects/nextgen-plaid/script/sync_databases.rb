#!/usr/bin/env ruby
# Database Synchronization Script for NextGen Plaid
# Purpose: Sync development databases from remote server (192.168.4.253) to local
# Features: Dry-run mode, automatic local backup, streaming sync, validation
# Usage: ruby script/sync_databases.rb [options]

require 'open3'
require 'fileutils'
require 'time'
require 'optparse'

module DatabaseSync
  # Configuration with environment variable defaults
  class Config
    attr_accessor :remote_host, :remote_user, :ssh_port,
                  :remote_pg_dump_path, :remote_psql_path,
                  :local_pg_restore_path, :local_psql_path,
                  :backup_dir, :log_dir, :dry_run, :backup_existing,
                  :stream, :selected_databases

    def initialize
      # SSH Configuration
      @remote_host = ENV['REMOTE_HOST'] || '192.168.4.253'
      @remote_user = ENV['REMOTE_USER'] || ENV['USER']
      @ssh_port = ENV['SSH_PORT'] || '22'

      # PostgreSQL paths (Homebrew installation defaults)
      @remote_psql_path = ENV['REMOTE_PSQL_PATH'] || '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql'
      @remote_pg_dump_path = ENV['REMOTE_PG_DUMP_PATH'] || '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump'
      @local_psql_path = ENV['LOCAL_PSQL_PATH'] || '/opt/homebrew/opt/postgresql@16/bin/psql'
      @local_pg_restore_path = ENV['LOCAL_PG_RESTORE_PATH'] || '/opt/homebrew/opt/postgresql@16/bin/pg_restore'

      # Directories
      @backup_dir = ENV['BACKUP_DIR'] || './tmp/db_backups'
      @log_dir = ENV['LOG_DIR'] || './log'

      # Options (can be overridden via command line)
      @dry_run = false
      @backup_existing = true
      @stream = true
      @selected_databases = [] # empty means all
    end

    # Database registry - development databases only
    DATABASES = {
      primary: {
        remote: 'nextgen_plaid_development',
        local: 'nextgen_plaid_development',
        shard: :primary
      },
      queue: {
        remote: 'nextgen_plaid_development_queue',
        local: 'nextgen_plaid_development_queue',
        shard: :solid_queue
      },
      cable: {
        remote: 'nextgen_plaid_development_cable',
        local: 'nextgen_plaid_development_cable',
        shard: :cable
      }
    }.freeze

    def databases
      DATABASES
    end

    # Return filtered databases based on selected_databases
    def selected_db_keys
      if @selected_databases.empty?
        databases.keys
      else
        @selected_databases.map(&:to_sym) & databases.keys
      end
    end
  end
end
class DatabaseSync::Sync
  attr_reader :config, :logger

  def initialize(config = nil)
    @config = config || DatabaseSync::Config.new
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end
    setup_directories
  end

  def setup_directories
    FileUtils.mkdir_p(@config.backup_dir)
    FileUtils.mkdir_p(@config.log_dir) if @config.log_dir
  end

  # Run a shell command, respecting dry-run mode
  # Returns [success, output, error]
  def run_command(cmd, description)
    logger.info(description)
    logger.debug("Command: #{cmd}") if @config.dry_run

    return [ true, nil, nil ] if @config.dry_run

    stdout, stderr, status = Open3.capture3(cmd)

    if status.success?
      logger.info("✓ Success")
      logger.debug("Output: #{stdout.strip}") unless stdout.strip.empty?
      [ true, stdout.strip, stderr.strip ]
    else
      logger.error("✗ Failed: #{stderr.strip}")
      [ false, stdout.strip, stderr.strip ]
    end
  end

  # Run a pipe command (command1 | command2)
  def run_pipe_command(cmd1, cmd2, description)
    full_cmd = "#{cmd1} | #{cmd2}"
    logger.info(description)
    logger.debug("Pipe command: #{full_cmd}") if @config.dry_run

    return [ true, nil, nil ] if @config.dry_run

    # Use bash -c to handle pipe properly
    stdout, stderr, status = Open3.capture3('bash', '-c', full_cmd)

    if status.success?
      logger.info("✓ Success")
      [ true, stdout.strip, stderr.strip ]
    else
      logger.error("✗ Failed: #{stderr.strip}")
      [ false, stdout.strip, stderr.strip ]
    end
  end

  # Test SSH connection
  def test_ssh_connection
    cmd = "ssh -p #{@config.ssh_port} #{@config.remote_user}@#{@config.remote_host} 'echo SSH connection successful'"
    success, _, _ = run_command(cmd, "Testing SSH connection to #{@config.remote_host}")
    success
  end

  # Test PostgreSQL connection (remote or local)
  def test_postgres_connection(host_type, psql_path)
    if host_type == :remote
      cmd = "ssh -p #{@config.ssh_port} #{@config.remote_user}@#{@config.remote_host} '#{psql_path} -c \"SELECT version();\"'"
    else
      cmd = "#{psql_path} -c \"SELECT version();\""
    end

    success, _, _ = run_command(cmd, "Testing PostgreSQL connection (#{host_type})")
    success
  end

  # Backup local database using pg_dump (custom format)
  def backup_local_database(db_name)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_file = "#{@config.backup_dir}/#{db_name}_#{timestamp}.dump"

    pg_dump_path = @config.local_pg_restore_path.sub('pg_restore', 'pg_dump')
    cmd = "#{pg_dump_path} --format=custom --no-owner --no-acl -d #{db_name} -f #{backup_file}"

    success, _, _ = run_command(cmd, "Backing up local database #{db_name}")
    if success && !@config.dry_run
      logger.info("Backup saved to: #{backup_file}")
      backup_file
    else
      nil
    end
  end

  # Drop local database (terminate connections first)
  def drop_local_database(db_name)
    # Terminate existing connections
    terminate_cmd = "#{@config.local_psql_path} -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '#{db_name}' AND pid <> pg_backend_pid();\" postgres"
    run_command(terminate_cmd, "Terminating connections to #{db_name}")

    # Drop database
    drop_cmd = "#{@config.local_psql_path} -c \"DROP DATABASE IF EXISTS #{db_name};\" postgres"
    run_command(drop_cmd, "Dropping database #{db_name}")
  end

  # Create local database
  def create_local_database(db_name)
    cmd = "#{@config.local_psql_path} -c \"CREATE DATABASE #{db_name};\" postgres"
    run_command(cmd, "Creating database #{db_name}")
  end
  # Stream sync: remote pg_dump -> local pg_restore via SSH pipe
  def stream_sync_database(remote_db_name, local_db_name)
    logger.info("Stream sync: #{remote_db_name} → #{local_db_name}")

    ssh_cmd = "ssh -p #{@config.ssh_port} #{@config.remote_user}@#{@config.remote_host}"
    pg_dump_cmd = "#{@config.remote_pg_dump_path} --format=custom --no-owner --no-acl #{remote_db_name}"
    pg_restore_cmd = "#{@config.local_pg_restore_path} --no-owner --no-acl --clean --if-exists -d #{local_db_name}"

    success, _, error = run_pipe_command(
      "#{ssh_cmd} '#{pg_dump_cmd}'",
      pg_restore_cmd,
      "Stream sync #{remote_db_name} → #{local_db_name}"
    )

    success
  end

  # Verify database by counting tables
  def verify_database(db_name)
    cmd = "#{@config.local_psql_path} -d #{db_name} -c \"SELECT COUNT(*) AS table_count FROM pg_tables WHERE schemaname = 'public';\""
    success, output, _ = run_command(cmd, "Verifying database #{db_name}")
    if success && output =~ /\d+/
      logger.info("Verification: #{output.strip} tables in #{db_name}")
      true
    else
      logger.warn("Verification failed for #{db_name}")
      false
    end
  end

  # Sync a single database (with backup if enabled)
  def sync_database(db_key)
    db = @config.databases[db_key]
    raise "Unknown database key: #{db_key}" unless db

    remote_db = db[:remote]
    local_db = db[:local]

    logger.info("\n" + "="*60)
    logger.info("Syncing #{remote_db} → #{local_db}")
    logger.info("="*60)

    # Step 1: Backup existing local database
    if @config.backup_existing
      backup_file = backup_local_database(local_db)
      logger.warn("Backup failed or skipped") unless backup_file
    end

    # Step 2: Drop and recreate local database
    drop_local_database(local_db)
    create_local_database(local_db)

    # Step 3: Stream sync
    unless stream_sync_database(remote_db, local_db)
      logger.error("Stream sync failed for #{remote_db}")
      return false
    end

    # Step 4: Verify restoration
    unless verify_database(local_db)
      logger.warn("Verification failed for #{local_db}, but sync may have succeeded")
    end

    logger.info("✓ Sync completed for #{remote_db} → #{local_db}")
    true
  end

  # Sync all selected databases
  def sync_all
    logger.info("Starting database sync from #{@config.remote_host}")
    logger.info("Dry run: #{@config.dry_run}")
    logger.info("Backup existing: #{@config.backup_existing}")
    logger.info("Streaming: #{@config.stream}")
    logger.info("Selected databases: #{@config.selected_db_keys.join(', ')}")
    logger.info("-" * 60)

    # Test connections
    unless test_ssh_connection
      logger.error("SSH connection failed. Aborting.")
      return false
    end

    unless test_postgres_connection(:remote, @config.remote_psql_path)
      logger.error("Remote PostgreSQL connection failed. Aborting.")
      return false
    end

    unless test_postgres_connection(:local, @config.local_psql_path)
      logger.error("Local PostgreSQL connection failed. Aborting.")
      return false
    end

    # Sync each selected database
    success = true
    @config.selected_db_keys.each do |db_key|
      success = false unless sync_database(db_key)
    end

    if success
      logger.info("\n" + "="*60)
      logger.info("Database sync completed successfully!")
      logger.info("="*60)
    else
      logger.error("\n" + "="*60)
      logger.error("Database sync completed with errors!")
      logger.error("="*60)
    end

    success
  end
end
