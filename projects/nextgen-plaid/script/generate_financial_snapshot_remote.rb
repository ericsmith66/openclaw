#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to generate financial snapshot from REMOTE production server
# Usage: ruby script/generate_financial_snapshot_remote.rb

require 'json'
require 'open3'

class RemoteFinancialSnapshotGenerator
  REMOTE_HOST = ENV['REMOTE_HOST'] || '192.168.4.253'
  REMOTE_USER = ENV['REMOTE_USER'] || ENV['USER']
  SSH_PORT = ENV['SSH_PORT'] || '22'

  # Remote paths
  REMOTE_APP_DIR = '/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid'

  # Local output paths
  OUTPUT_DIR = '/Users/ericsmith66/Documents/Taxes/Taxes 2025/data/json'
  OUTPUT_FILE = 'financial_snapshot_2026_02.json'
  SUMMARY_FILE = '/Users/ericsmith66/Documents/Taxes/Taxes 2025/data/FINANCIAL_SNAPSHOT_2026_02_SUMMARY.md'

  def initialize
    @ssh_base = "ssh -p #{SSH_PORT} #{REMOTE_USER}@#{REMOTE_HOST}"
  end

  def generate
    puts "🔗 Connecting to production server at #{REMOTE_HOST}..."

    # First, copy the generator script to remote server
    puts "\n📤 Uploading generator script to remote server..."
    upload_script

    # Run the script on remote server
    puts "\n🚀 Running snapshot generator on production server..."
    run_remote_generator

    # Download the generated files
    puts "\n📥 Downloading generated files..."
    download_files

    puts "\n✅ Remote financial snapshot generated successfully!"
    puts "JSON file: #{File.join(OUTPUT_DIR, OUTPUT_FILE)}"
    puts "Summary file: #{SUMMARY_FILE}"
  end

  private

  def upload_script
    local_script = 'script/generate_financial_snapshot.rb'
    remote_script = "#{REMOTE_APP_DIR}/script/generate_financial_snapshot.rb"

    cmd = "scp -P #{SSH_PORT} #{local_script} #{REMOTE_USER}@#{REMOTE_HOST}:#{remote_script}"
    stdout, stderr, status = Open3.capture3(cmd)

    unless status.success?
      puts "❌ Failed to upload script: #{stderr}"
      exit 1
    end

    puts "  ✓ Script uploaded"
  end

  def run_remote_generator
    # Run the generator script on remote server in production environment
    remote_cmd = "cd #{REMOTE_APP_DIR} && RAILS_ENV=production bundle exec rails runner script/generate_financial_snapshot.rb"
    cmd = "#{@ssh_base} '#{remote_cmd}'"

    puts "  Executing: #{remote_cmd}"
    stdout, stderr, status = Open3.capture3(cmd)

    puts stdout unless stdout.empty?

    if stderr.include?('ERROR') || stderr.include?('error:')
      puts "⚠️  Warnings/Errors: #{stderr}"
    end

    unless status.success?
      puts "❌ Failed to run generator on remote: #{stderr}"
      exit 1
    end

    puts "  ✓ Generator completed on remote server"
  end

  def download_files
    FileUtils.mkdir_p(OUTPUT_DIR)

    # Download JSON file
    remote_json = "#{REMOTE_APP_DIR}/../../Documents/Taxes/Taxes\\ 2025/data/json/#{OUTPUT_FILE}"
    local_json = File.join(OUTPUT_DIR, OUTPUT_FILE)

    cmd = "scp -P #{SSH_PORT} #{REMOTE_USER}@#{REMOTE_HOST}:#{remote_json} #{local_json}"
    stdout, stderr, status = Open3.capture3(cmd)

    unless status.success?
      puts "❌ Failed to download JSON: #{stderr}"
      exit 1
    end

    puts "  ✓ Downloaded #{OUTPUT_FILE} (#{File.size(local_json)} bytes)"

    # Download summary file
    remote_summary = "#{REMOTE_APP_DIR}/../../Documents/Taxes/Taxes\\ 2025/data/FINANCIAL_SNAPSHOT_2026_02_SUMMARY.md"

    cmd = "scp -P #{SSH_PORT} #{REMOTE_USER}@#{REMOTE_HOST}:#{remote_summary} #{SUMMARY_FILE}"
    stdout, stderr, status = Open3.capture3(cmd)

    unless status.success?
      puts "❌ Failed to download summary: #{stderr}"
      exit 1
    end

    puts "  ✓ Downloaded summary (#{File.size(SUMMARY_FILE)} bytes)"
  end
end

# Run the generator
begin
  generator = RemoteFinancialSnapshotGenerator.new
  generator.generate
rescue StandardError => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
