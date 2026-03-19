#!/usr/bin/env ruby
# UniFi Security Audit Script
# Purpose: Automated collection of UniFi logs and security audit
# Context: Response to eureka-homekit credential exposure (2026-02-18)
#
# Usage:
#   export UNIFI_HOST="192.168.4.1"
#   export UNIFI_ADMIN_USER="your_admin_username"
#   export UNIFI_ADMIN_PASS="your_admin_password"
#   ruby scripts/unifi-security-audit.rb

require 'json'
require 'time'
require 'net/http'
require 'uri'
require 'openssl'

# Configuration
UNIFI_HOST = ENV['UNIFI_HOST'] || '192.168.4.1'
UNIFI_PORT = ENV['UNIFI_PORT'] || '443'  # UDM-SE uses 443 for UniFi OS Console
UNIFI_USER = ENV['UNIFI_ADMIN_USER']
UNIFI_PASS = ENV['UNIFI_ADMIN_PASS']
UNIFI_SITE = ENV['UNIFI_SITE'] || 'default'

# Exposure window from incident
EXPOSURE_START = Time.parse('2026-02-06T00:00:00Z')
EXPOSURE_END = Time.parse('2026-02-18T23:59:59Z')

# Output
OUTPUT_FILE = "unifi-audit-report-#{Time.now.strftime('%Y-%m-%d')}.json"

# Colors for terminal output
class String
  def red; "\033[31m#{self}\033[0m"; end
  def green; "\033[32m#{self}\033[0m"; end
  def yellow; "\033[33m#{self}\033[0m"; end
  def blue; "\033[34m#{self}\033[0m"; end
  def bold; "\033[1m#{self}\033[0m"; end
end

puts "=" * 80
puts "UniFi Security Audit".bold.blue
puts "Incident: Eureka-HomeKit Credential Exposure"
puts "Exposure Window: #{EXPOSURE_START.strftime('%Y-%m-%d')} to #{EXPOSURE_END.strftime('%Y-%m-%d')}"
puts "=" * 80
puts

# Validate configuration
unless UNIFI_USER && UNIFI_PASS
  puts "❌ ERROR: Missing credentials".red.bold
  puts "Set UNIFI_ADMIN_USER and UNIFI_ADMIN_PASS environment variables"
  exit 1
end

# Simple UniFi API client
class UniFiClient
  def initialize(host, port, username, password, site = 'default')
    @host = host
    @port = port
    @username = username
    @password = password
    @site = site
    @cookies = nil
    @base_uri = URI("https://#{@host}:#{@port}")
    @use_proxy = (port.to_i == 443)  # UDM-SE on 443 needs /proxy/network prefix
  end

  def login
    puts "🔐 Authenticating to UniFi Controller...".blue
    puts "  Connecting to: https://#{@host}:#{@port}".blue

    # Try UDM/UniFi OS path first (/api/auth/login)
    uri = URI.join(@base_uri, '/api/auth/login')
    puts "  Trying: #{uri}".blue if ENV['DEBUG']
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = JSON.generate({
      username: @username,
      password: @password
    })

    response = http_request(request)

    # If 404, try legacy controller path (/api/login)
    if response.code == '404'
      puts "  ℹ️  Trying legacy controller path...".blue
      uri = URI.join(@base_uri, '/api/login')
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'application/json'
      request.body = JSON.generate({
        username: @username,
        password: @password
      })
      response = http_request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      @cookies = response['set-cookie']
      puts "✅ Authentication successful".green
      true
    else
      puts "❌ Authentication failed: #{response.code} #{response.message}".red
      puts "  URL attempted: #{uri}".yellow
      false
    end
  end

  def get_clients
    puts "📡 Fetching client list...".blue
    path = "/api/s/#{@site}/stat/sta"
    path = "/proxy/network#{path}" if @use_proxy
    get(path)
  end

  def get_events(start_time, end_time, type = nil)
    puts "📋 Fetching events (#{start_time.strftime('%Y-%m-%d')} to #{end_time.strftime('%Y-%m-%d')})...".blue

    params = {
      start: (start_time.to_i * 1000),
      end: (end_time.to_i * 1000)
    }
    params[:type] = type if type

    path = "/api/s/#{@site}/stat/event"
    path = "/proxy/network#{path}" if @use_proxy
    get(path, params)
  end

  def get_firewall_rules
    puts "🛡️  Fetching firewall rules...".blue
    path = "/api/s/#{@site}/rest/firewallrule"
    path = "/proxy/network#{path}" if @use_proxy
    get(path)
  end

  def get_port_forwards
    puts "🚪 Fetching port forwarding rules...".blue
    path = "/api/s/#{@site}/rest/portforward"
    path = "/proxy/network#{path}" if @use_proxy
    get(path)
  end

  def get_admins
    puts "👤 Fetching administrator accounts...".blue
    path = "/api/s/#{@site}/cmd/sitemgr"
    path = "/proxy/network#{path}" if @use_proxy
    get(path, { cmd: 'get-admins' })
  end

  private

  def get(path, params = {})
    uri = URI.join(@base_uri, path)
    uri.query = URI.encode_www_form(params) unless params.empty?

    request = Net::HTTP::Get.new(uri)
    request['Cookie'] = @cookies if @cookies

    response = http_request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['data'] || data
    else
      puts "⚠️  Request failed: #{response.code} #{response.message}".yellow
      []
    end
  end

  def http_request(request)
    http = Net::HTTP.new(@base_uri.host, @base_uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # WARNING: Insecure for production
    http.read_timeout = 10
    http.open_timeout = 10

    begin
      http.request(request)
    rescue StandardError => e
      puts "  ⚠️  Network error: #{e.class} - #{e.message}".yellow
      raise
    end
  end
end

# Analysis functions
def analyze_auth_events(events, exposure_start, exposure_end)
  puts "\n🔍 Analyzing authentication events...".blue.bold

  exposure_events = events.select do |event|
    event_time = Time.at(event['time'] / 1000.0)
    event_time >= exposure_start && event_time <= exposure_end
  end

  suspicious_logins = exposure_events.select do |event|
    # Flag logins from non-local IPs
    src_ip = event['src_ip'] || event['ip']
    src_ip && !src_ip.start_with?('192.168.4.')
  end

  failed_logins = exposure_events.select do |event|
    event['key'] == 'EVT_LU_Failure' || event['msg']&.include?('failed')
  end

  puts "  Total events in exposure window: #{exposure_events.count}"
  puts "  Suspicious external logins: #{suspicious_logins.count} #{'⚠️' if suspicious_logins.count > 0}"
  puts "  Failed login attempts: #{failed_logins.count} #{'⚠️' if failed_logins.count > 5}"

  {
    total: exposure_events.count,
    suspicious: suspicious_logins,
    failed: failed_logins
  }
end

def analyze_clients(clients)
  puts "\n🔍 Analyzing connected clients...".blue.bold

  unknown_clients = clients.select do |client|
    hostname = client['hostname'] || client['name']
    hostname.nil? || hostname.empty? || hostname =~ /android-|unknown|espressif/i
  end

  high_usage_clients = clients.select do |client|
    tx_bytes = client['tx_bytes'] || 0
    rx_bytes = client['rx_bytes'] || 0
    total = tx_bytes + rx_bytes
    total > 1_000_000_000 # > 1 GB
  end

  puts "  Total clients: #{clients.count}"
  puts "  Unknown/generic hostnames: #{unknown_clients.count} #{'⚠️' if unknown_clients.count > 0}"
  puts "  High bandwidth usage (>1GB): #{high_usage_clients.count}"

  {
    total: clients.count,
    unknown: unknown_clients,
    high_usage: high_usage_clients
  }
end

def analyze_firewall_rules(rules)
  puts "\n🔍 Analyzing firewall rules...".blue.bold

  allow_all_rules = rules.select do |rule|
    rule['action'] == 'accept' &&
    (rule['src_address'] == 'any' || rule['dst_address'] == 'any')
  end

  wan_to_lan_rules = rules.select do |rule|
    rule['action'] == 'accept' &&
    rule['src_networkconf_type'] == 'WAN'
  end

  puts "  Total firewall rules: #{rules.count}"
  puts "  'Allow All' rules: #{allow_all_rules.count} #{'⚠️' if allow_all_rules.count > 0}"
  puts "  WAN→LAN allow rules: #{wan_to_lan_rules.count}"

  {
    total: rules.count,
    allow_all: allow_all_rules,
    wan_to_lan: wan_to_lan_rules
  }
end

def analyze_port_forwards(forwards)
  puts "\n🔍 Analyzing port forwarding rules...".blue.bold

  enabled_forwards = forwards.select { |f| f['enabled'] }
  admin_port_forwards = enabled_forwards.select do |f|
    admin_ports = [ 22, 443, 8443, 3389 ]
    fwd_port = f['fwd_port'] || f['dst_port']
    admin_ports.include?(fwd_port.to_i)
  end

  puts "  Total port forwards: #{forwards.count}"
  puts "  Enabled: #{enabled_forwards.count}"
  puts "  Admin port forwards: #{admin_port_forwards.count} #{'⚠️' if admin_port_forwards.count > 0}"

  {
    total: forwards.count,
    enabled: enabled_forwards,
    admin_ports: admin_port_forwards
  }
end

# Main execution
begin
  client = UniFiClient.new(UNIFI_HOST, UNIFI_PORT, UNIFI_USER, UNIFI_PASS, UNIFI_SITE)

  unless client.login
    puts "\n❌ Failed to authenticate. Check credentials and controller access.".red.bold
    exit 1
  end

  puts "\n" + "─" * 80

  # Collect data
  clients = client.get_clients
  events = client.get_events(EXPOSURE_START, EXPOSURE_END)
  firewall_rules = client.get_firewall_rules
  port_forwards = client.get_port_forwards
  admins = client.get_admins

  # Analyze
  auth_analysis = analyze_auth_events(events, EXPOSURE_START, EXPOSURE_END)
  client_analysis = analyze_clients(clients)
  firewall_analysis = analyze_firewall_rules(firewall_rules)
  port_forward_analysis = analyze_port_forwards(port_forwards)

  # Generate report
  report = {
    audit_metadata: {
      timestamp: Time.now.iso8601,
      operator: ENV['USER'] || 'unknown',
      unifi_host: UNIFI_HOST,
      site: UNIFI_SITE
    },
    exposure_window: {
      start: EXPOSURE_START.iso8601,
      end: EXPOSURE_END.iso8601,
      duration_days: ((EXPOSURE_END - EXPOSURE_START) / 86400).round(1)
    },
    summary: {
      authentication_events: auth_analysis[:total],
      suspicious_logins: auth_analysis[:suspicious].count,
      failed_logins: auth_analysis[:failed].count,
      total_clients: client_analysis[:total],
      unknown_clients: client_analysis[:unknown].count,
      firewall_rules: firewall_analysis[:total],
      port_forwards: port_forward_analysis[:total],
      enabled_port_forwards: port_forward_analysis[:enabled].count
    },
    findings: {
      high_severity: [],
      medium_severity: [],
      low_severity: []
    },
    detailed_data: {
      suspicious_logins: auth_analysis[:suspicious].map { |e|
        {
          time: Time.at(e['time'] / 1000.0).iso8601,
          user: e['user'],
          src_ip: e['src_ip'] || e['ip'],
          message: e['msg']
        }
      },
      unknown_clients: client_analysis[:unknown].map { |c|
        {
          mac: c['mac'],
          ip: c['ip'],
          hostname: c['hostname'] || c['name'] || 'unknown',
          first_seen: c['first_seen'] ? Time.at(c['first_seen']).iso8601 : nil,
          last_seen: c['last_seen'] ? Time.at(c['last_seen']).iso8601 : nil
        }
      },
      admin_port_forwards: port_forward_analysis[:admin_ports].map { |f|
        {
          name: f['name'],
          dst_port: f['dst_port'],
          fwd: f['fwd'],
          fwd_port: f['fwd_port'],
          enabled: f['enabled']
        }
      }
    }
  }

  # Classify findings
  if auth_analysis[:suspicious].count > 0
    report[:findings][:high_severity] << {
      type: 'suspicious_login',
      severity: 'HIGH',
      description: "#{auth_analysis[:suspicious].count} login(s) from external IP addresses detected",
      recommendation: "Review detailed_data.suspicious_logins and investigate each event"
    }
  end

  if auth_analysis[:failed].count > 10
    report[:findings][:medium_severity] << {
      type: 'failed_logins',
      severity: 'MEDIUM',
      description: "#{auth_analysis[:failed].count} failed login attempts detected",
      recommendation: "Review logs for brute force attempts; consider IP blocking"
    }
  end

  if port_forward_analysis[:admin_ports].count > 0
    report[:findings][:high_severity] << {
      type: 'admin_port_forwarding',
      severity: 'HIGH',
      description: "#{port_forward_analysis[:admin_ports].count} port forward(s) to admin ports (22, 443, 3389, 8443)",
      recommendation: "Review necessity; disable if not required; use VPN instead"
    }
  end

  if client_analysis[:unknown].count > 5
    report[:findings][:medium_severity] << {
      type: 'unknown_clients',
      severity: 'MEDIUM',
      description: "#{client_analysis[:unknown].count} clients with unknown/generic hostnames",
      recommendation: "Review detailed_data.unknown_clients and identify each device"
    }
  end

  # Overall status
  report[:overall_status] = if report[:findings][:high_severity].any?
    'FAIL - High severity issues found'
  elsif report[:findings][:medium_severity].any?
    'WARN - Medium severity issues found'
  else
    'PASS - No security issues detected'
  end

  # Save report
  File.write(OUTPUT_FILE, JSON.pretty_generate(report))

  puts "\n" + "─" * 80
  puts "\n📊 Audit Summary".bold.blue
  puts "─" * 80

  status_color = case report[:overall_status]
  when /FAIL/ then :red
  when /WARN/ then :yellow
  else :green
  end

  puts "Status: #{report[:overall_status].send(status_color).bold}"
  puts "\nFindings:"
  puts "  High Severity: #{report[:findings][:high_severity].count} #{'🚨' if report[:findings][:high_severity].any?}"
  puts "  Medium Severity: #{report[:findings][:medium_severity].count} #{'⚠️' if report[:findings][:medium_severity].any?}"
  puts "  Low Severity: #{report[:findings][:low_severity].count}"

  if report[:findings][:high_severity].any? || report[:findings][:medium_severity].any?
    puts "\n⚠️  Issues detected:".yellow.bold
    (report[:findings][:high_severity] + report[:findings][:medium_severity]).each do |finding|
      puts "  • [#{finding[:severity]}] #{finding[:description]}"
    end
  else
    puts "\n✅ No security issues detected during exposure window".green.bold
  end

  puts "\n📄 Full report saved to: #{OUTPUT_FILE}".blue
  puts "=" * 80

rescue StandardError => e
  puts "\n❌ Error during audit: #{e.message}".red.bold
  puts e.backtrace.join("\n").yellow if ENV['DEBUG']
  exit 1
end
