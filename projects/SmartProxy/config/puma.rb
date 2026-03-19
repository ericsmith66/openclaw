#!/usr/bin/env puma

# Puma configuration for SmartProxy production

# Application root
app_dir = File.expand_path("../..", __FILE__)
directory app_dir

# Environment
environment ENV.fetch("RACK_ENV") { "production" }

# Port
port ENV.fetch("SMART_PROXY_PORT") { 3001 }

# Threads
threads_count = ENV.fetch("PUMA_THREADS") { 5 }.to_i
threads threads_count, threads_count

# Bind
bind "tcp://0.0.0.0:#{ENV.fetch('SMART_PROXY_PORT') { 3001 }}"

# Logging
stdout_redirect "#{app_dir}/log/puma.stdout.log", "#{app_dir}/log/puma.stderr.log", true

# Pidfile
pidfile "#{app_dir}/tmp/puma.pid"

# State
state_path "#{app_dir}/tmp/puma.state"
