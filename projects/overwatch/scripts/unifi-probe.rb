#!/usr/bin/env ruby
# Quick diagnostic to find the correct UniFi API endpoint

require 'net/http'
require 'uri'
require 'openssl'
require 'json'

UNIFI_HOST = ENV['UNIFI_HOST'] || '192.168.4.1'
UNIFI_PORT = ENV['UNIFI_PORT'] || '8443'
UNIFI_USER = ENV['UNIFI_ADMIN_USER']
UNIFI_PASS = ENV['UNIFI_ADMIN_PASS']

unless UNIFI_USER && UNIFI_PASS
  puts "❌ Set UNIFI_ADMIN_USER and UNIFI_ADMIN_PASS"
  exit 1
end

def try_endpoint(host, port, path, username, password)
  uri = URI("https://#{host}:#{port}#{path}")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 5
  http.open_timeout = 5

  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  request.body = JSON.generate({ username: username, password: password })

  begin
    response = http.request(request)
    puts "  #{path.ljust(30)} → #{response.code} #{response.message}"

    if response.is_a?(Net::HTTPSuccess)
      puts "    ✅ SUCCESS! This is the correct endpoint."
      return true
    end

    false
  rescue StandardError => e
    puts "  #{path.ljust(30)} → ERROR: #{e.message}"
    false
  end
end

puts "Probing UniFi Controller at #{UNIFI_HOST}:#{UNIFI_PORT}..."
puts "=" * 60

endpoints = [
  '/api/auth/login',           # UDM/UniFi OS
  '/api/login',                # Legacy controller
  '/api/v2/login',             # Possible v2 API
  '/proxy/network/api/login',  # UDM proxy path
  '/v2/api/login'             # Another possible path
]

success = false
endpoints.each do |path|
  if try_endpoint(UNIFI_HOST, UNIFI_PORT, path, UNIFI_USER, UNIFI_PASS)
    success = true
    break
  end
end

unless success
  puts "\n❌ None of the known endpoints worked."
  puts "\nPlease check:"
  puts "  1. Can you access https://#{UNIFI_HOST}:#{UNIFI_PORT} in browser?"
  puts "  2. Are you using the local admin account (not cloud account)?"
  puts "  3. Is the controller running on a different port?"
end
