#!/usr/bin/env ruby
# Test database connectivity for NextGen Plaid sync
# This script tests SSH and PostgreSQL connectivity

require 'open3'

def run_command(cmd, description)
  puts "[#{Time.now}] #{description}"
  puts "  Command: #{cmd}"

  stdout, stderr, status = Open3.capture3(cmd)

  if status.success?
    puts "  ✓ Success"
    puts "  Output: #{stdout.strip}" unless stdout.strip.empty?
    stdout.strip
  else
    puts "  ✗ Failed: #{stderr.strip}"
    nil
  end
end

def test_ssh(host, user, port = '22')
  cmd = "ssh -p #{port} #{user}@#{host} 'echo SSH connection successful && whoami && hostname'"
  run_command(cmd, "Testing SSH to #{host}")
end

def test_postgres_remote(host, user, port, psql_path)
  ssh_cmd = "ssh -p #{port} #{user}@#{host} '#{psql_path} -l'"
  run_command(ssh_cmd, "Listing remote PostgreSQL databases")
end

def test_postgres_local(psql_path)
  cmd = "#{psql_path} -l"
  run_command(cmd, "Listing local PostgreSQL databases")
end

def test_pg_dump_remote(host, user, port, pg_dump_path, database)
  ssh_cmd = "ssh -p #{port} #{user}@#{host} '#{pg_dump_path} --version'"
  run_command(ssh_cmd, "Testing remote pg_dump version")

  # Test dump of a small table or schema only
  ssh_cmd = "ssh -p #{port} #{user}@#{host} '#{pg_dump_path} --schema-only #{database} 2>/dev/null | head -20'"
  run_command(ssh_cmd, "Testing remote pg_dump schema-only for #{database}")
end

def main
  puts "=" * 60
  puts "Database Connectivity Test"
  puts "=" * 60

  config = {
    remote_host: '192.168.4.253',
    remote_user: ENV['USER'] || 'ericsmith66',
    ssh_port: '22',
    remote_psql_path: '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql',
    remote_pg_dump_path: '/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump',
    local_psql_path: '/opt/homebrew/opt/postgresql@16/bin/psql',
    test_database: 'nextgen_plaid_development'
  }

  puts "Configuration:"
  config.each { |k, v| puts "  #{k}: #{v}" }
  puts

  # Test 1: SSH connection
  ssh_result = test_ssh(config[:remote_host], config[:remote_user], config[:ssh_port])
  return unless ssh_result

  # Test 2: Remote PostgreSQL
  remote_db_result = test_postgres_remote(
    config[:remote_host],
    config[:remote_user],
    config[:ssh_port],
    config[:remote_psql_path]
  )

  # Test 3: Local PostgreSQL
  local_db_result = test_postgres_local(config[:local_psql_path])

  # Test 4: Remote pg_dump
  if remote_db_result
    test_pg_dump_remote(
      config[:remote_host],
      config[:remote_user],
      config[:ssh_port],
      config[:remote_pg_dump_path],
      config[:test_database]
    )
  end

  # Check for NextGen Plaid databases
  puts "\n" + "=" * 60
  puts "Checking for NextGen Plaid databases"
  puts "=" * 60

  nextgen_databases = [
    'nextgen_plaid_development',
    'nextgen_plaid_development_queue',
    'nextgen_plaid_development_cable'
  ]

  # Check remote
  puts "\nRemote databases:"
  nextgen_databases.each do |db|
    ssh_cmd = "ssh -p #{config[:ssh_port]} #{config[:remote_user]}@#{config[:remote_host]} '#{config[:remote_psql_path]} -d #{db} -c \"SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';\" 2>/dev/null'"
    stdout, stderr, status = Open3.capture3(ssh_cmd)

    if status.success? && stdout =~ /\d+/
      puts "  ✓ #{db}: #{stdout.strip} tables"
    else
      puts "  ✗ #{db}: Not found or error"
    end
  end

  # Check local
  puts "\nLocal databases:"
  nextgen_databases.each do |db|
    cmd = "#{config[:local_psql_path]} -d #{db} -c \"SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';\" 2>/dev/null"
    stdout, stderr, status = Open3.capture3(cmd)

    if status.success? && stdout =~ /\d+/
      puts "  ✓ #{db}: #{stdout.strip} tables"
    else
      puts "  ✗ #{db}: Not found or error"
    end
  end

  puts "\n" + "=" * 60
  puts "Summary"
  puts "=" * 60
  puts "SSH connection: #{ssh_result ? '✓ OK' : '✗ FAILED'}"
  puts "Remote PostgreSQL: #{remote_db_result ? '✓ OK' : '✗ FAILED'}"
  puts "Local PostgreSQL: #{local_db_result ? '✓ OK' : '✗ FAILED'}"
  puts "\nNext steps:"
  puts "1. If all tests pass, the database sync should work"
  puts "2. If databases don't exist locally, they will be created"
  puts "3. Review the prototype script for implementation"
end

if __FILE__ == $0
  main
end
