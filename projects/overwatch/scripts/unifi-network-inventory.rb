#!/usr/bin/env ruby
# UniFi Network Inventory Script
# Purpose: Document complete network infrastructure via read-only API
# Generates comprehensive network documentation for Overwatch
#
# Usage:
#   export UNIFI_HOST="192.168.4.1"
#   export UNIFI_API_KEY="your_readonly_api_key"
#   ruby scripts/unifi-network-inventory.rb

require 'json'
require 'time'
require 'net/http'
require 'uri'
require 'openssl'

# Configuration
UNIFI_HOST = ENV['UNIFI_HOST'] || '192.168.4.1'
UNIFI_PORT = ENV['UNIFI_PORT'] || '443'
UNIFI_API_KEY = ENV['UNIFI_API_KEY']
UNIFI_USER = ENV['UNIFI_ADMIN_USER']
UNIFI_PASS = ENV['UNIFI_ADMIN_PASS']
UNIFI_SITE = ENV['UNIFI_SITE'] || 'default'

# Output
OUTPUT_DIR = 'docs/network-inventory'
MARKDOWN_FILE = "#{OUTPUT_DIR}/network-inventory-#{Time.now.strftime('%Y-%m-%d')}.md"
JSON_FILE = "#{OUTPUT_DIR}/network-inventory-#{Time.now.strftime('%Y-%m-%d')}.json"

# Colors for terminal output
class String
  def red; "\033[31m#{self}\033[0m"; end
  def green; "\033[32m#{self}\033[0m"; end
  def yellow; "\033[33m#{self}\033[0m"; end
  def blue; "\033[34m#{self}\033[0m"; end
  def bold; "\033[1m#{self}\033[0m"; end
end

puts "=" * 80
puts "UniFi Network Inventory".bold.blue
puts "Documenting network infrastructure for Overwatch"
puts "=" * 80
puts

# Validate configuration
unless UNIFI_API_KEY || (UNIFI_USER && UNIFI_PASS)
  puts "❌ ERROR: Missing credentials".red.bold
  puts "Set either:"
  puts "  - UNIFI_API_KEY (cloud API key)"
  puts "  - UNIFI_ADMIN_USER and UNIFI_ADMIN_PASS (local admin)"
  exit 1
end

auth_method = UNIFI_API_KEY ? 'API Key' : 'Username/Password'
puts "Authentication: #{auth_method}".blue

# UniFi API client with API key or username/password authentication
class UniFiInventoryClient
  def initialize(host, port, api_key = nil, username = nil, password = nil, site = 'default')
    @host = host
    @port = port
    @api_key = api_key
    @username = username
    @password = password
    @site = site
    @cookies = nil
    @base_uri = URI("https://#{@host}:#{@port}")
    @use_proxy = (port.to_i == 443)

    # If using username/password, login first
    login if @username && @password
  end

  def login
    puts "🔐 Authenticating to UniFi Controller...".blue

    uri = URI.join(@base_uri, '/api/auth/login')
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = JSON.generate({
      username: @username,
      password: @password
    })

    response = http_request(request)

    if response.is_a?(Net::HTTPSuccess)
      @cookies = response['set-cookie']
      puts "  ✅ Authentication successful".green
      true
    else
      puts "  ❌ Authentication failed: #{response.code} #{response.message}".red
      exit 1
    end
  end

  def get_system_info
    puts "📋 Fetching system information...".blue
    get('/proxy/network/api/s/default/stat/sysinfo')
  end

  def get_devices
    puts "📡 Fetching UniFi devices (APs, switches, gateways)...".blue
    get('/proxy/network/api/s/default/stat/device')
  end

  def get_clients
    puts "👥 Fetching connected clients...".blue
    get('/proxy/network/api/s/default/stat/sta')
  end

  def get_networks
    puts "🌐 Fetching network configuration...".blue
    get('/proxy/network/api/s/default/rest/networkconf')
  end

  def get_port_forwards
    puts "🚪 Fetching port forwarding rules...".blue
    get('/proxy/network/api/s/default/rest/portforward')
  end

  def get_firewall_groups
    puts "🛡️  Fetching firewall groups...".blue
    get('/proxy/network/api/s/default/rest/firewallgroup')
  end

  def get_firewall_rules
    puts "🔥 Fetching firewall rules...".blue
    get('/proxy/network/api/s/default/rest/firewallrule')
  end

  def get_wireless_networks
    puts "📶 Fetching wireless networks (SSIDs)...".blue
    get('/proxy/network/api/s/default/rest/wlanconf')
  end

  def get_site_settings
    puts "⚙️  Fetching site settings...".blue
    get('/proxy/network/api/s/default/get/setting')
  end

  def get_dpi_stats
    puts "📊 Fetching DPI statistics...".blue
    get('/proxy/network/api/s/default/stat/stadpi')
  end

  private

  def get(path)
    uri = URI.join(@base_uri, path)

    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'

    # Use API key if available, otherwise use cookies from login
    if @api_key
      request['X-API-KEY'] = @api_key
      request['Authorization'] = "Bearer #{@api_key}"
    elsif @cookies
      request['Cookie'] = @cookies
    end

    response = http_request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data['data'] || data
    else
      puts "  ⚠️  Request failed: #{response.code} #{response.message}".yellow
      []
    end
  rescue StandardError => e
    puts "  ⚠️  Error: #{e.class} - #{e.message}".yellow
    []
  end

  def http_request(request)
    http = Net::HTTP.new(@base_uri.host, @base_uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 10
    http.open_timeout = 10
    http.request(request)
  end
end

# Helper functions
def categorize_clients(clients)
  wired = clients.select { |c| c['is_wired'] }
  wireless = clients.reject { |c| c['is_wired'] }

  {
    total: clients.count,
    wired: wired.count,
    wireless: wireless.count,
    guests: clients.select { |c| c['is_guest'] }.count,
    by_network: clients.group_by { |c| c['network'] || 'unknown' }
  }
end

def categorize_devices(devices)
  {
    total: devices.count,
    by_type: devices.group_by { |d| d['type'] },
    by_model: devices.group_by { |d| d['model'] },
    adopted: devices.select { |d| d['state'] == 1 }.count,
    online: devices.select { |d| d['state'] == 1 }.count
  }
end

def format_bytes(bytes)
  return "0 B" if bytes.nil? || bytes.zero?

  units = [ 'B', 'KB', 'MB', 'GB', 'TB' ]
  i = 0
  size = bytes.to_f

  while size >= 1024 && i < units.length - 1
    size /= 1024
    i += 1
  end

  "#{size.round(2)} #{units[i]}"
end

def format_uptime(seconds)
  return "Unknown" if seconds.nil?

  days = seconds / 86400
  hours = (seconds % 86400) / 3600
  minutes = (seconds % 3600) / 60

  parts = []
  parts << "#{days}d" if days > 0
  parts << "#{hours}h" if hours > 0
  parts << "#{minutes}m" if minutes > 0

  parts.any? ? parts.join(' ') : "< 1m"
end

# Generate markdown documentation
def generate_markdown(data, filename)
  File.open(filename, 'w') do |f|
    f.puts "# UniFi Network Infrastructure Inventory"
    f.puts "**Generated:** #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    f.puts "**Controller:** #{data[:system_info]['name'] || 'Unknown'}"
    f.puts "**Version:** #{data[:system_info]['version'] || 'Unknown'}"
    f.puts
    f.puts "---"
    f.puts

    # Overview
    f.puts "## Network Overview"
    f.puts
    f.puts "| Metric | Count |"
    f.puts "|--------|-------|"
    f.puts "| **UniFi Devices** | #{data[:device_stats][:total]} |"
    f.puts "| **Connected Clients** | #{data[:client_stats][:total]} |"
    f.puts "| **Wireless Clients** | #{data[:client_stats][:wireless]} |"
    f.puts "| **Wired Clients** | #{data[:client_stats][:wired]} |"
    f.puts "| **Networks (VLANs)** | #{data[:networks].count} |"
    f.puts "| **Wireless Networks (SSIDs)** | #{data[:wireless_networks].count} |"
    f.puts "| **Port Forwards** | #{data[:port_forwards].count} |"
    f.puts "| **Firewall Rules** | #{data[:firewall_rules].count} |"
    f.puts

    # UniFi Devices
    f.puts "## UniFi Infrastructure Devices"
    f.puts
    if data[:devices].any?
      f.puts "| Name | Type | Model | IP Address | MAC Address | Version | Uptime | Status |"
      f.puts "|------|------|-------|------------|-------------|---------|--------|--------|"
      data[:devices].sort_by { |d| d['type'] }.each do |device|
        name = device['name'] || 'Unnamed'
        type = device['type'] || 'unknown'
        model = device['model'] || 'unknown'
        ip = device['ip'] || 'N/A'
        mac = device['mac'] || 'N/A'
        version = device['version'] || 'N/A'
        uptime = format_uptime(device['uptime'])
        status = device['state'] == 1 ? '✅ Online' : '❌ Offline'

        f.puts "| #{name} | #{type} | #{model} | #{ip} | #{mac} | #{version} | #{uptime} | #{status} |"
      end
    else
      f.puts "*No UniFi devices found*"
    end
    f.puts

    # Networks/VLANs
    f.puts "## Networks (VLANs)"
    f.puts
    if data[:networks].any?
      f.puts "| Name | Purpose | VLAN ID | Network | DHCP | Domain |"
      f.puts "|------|---------|---------|---------|------|--------|"
      data[:networks].sort_by { |n| n['vlan'] || 0 }.each do |network|
        name = network['name'] || 'Unnamed'
        purpose = network['purpose'] || 'corporate'
        vlan = network['vlan'] || 'N/A'
        ip_subnet = network['ip_subnet'] || 'N/A'
        dhcp = network['dhcpd_enabled'] ? 'Enabled' : 'Disabled'
        domain = network['domain_name'] || 'N/A'

        f.puts "| #{name} | #{purpose} | #{vlan} | #{ip_subnet} | #{dhcp} | #{domain} |"
      end
    else
      f.puts "*No networks configured*"
    end
    f.puts

    # Wireless Networks (SSIDs)
    f.puts "## Wireless Networks (SSIDs)"
    f.puts
    if data[:wireless_networks].any?
      f.puts "| SSID | Security | Network | Enabled | Hidden | Guest |"
      f.puts "|------|----------|---------|---------|--------|-------|"
      data[:wireless_networks].each do |wlan|
        ssid = wlan['name'] || 'Unnamed'
        security = wlan['security'] || 'open'
        network = wlan['networkconf_id'] || 'default'
        enabled = wlan['enabled'] ? 'Yes' : 'No'
        hidden = wlan['hide_ssid'] ? 'Yes' : 'No'
        guest = wlan['is_guest'] ? 'Yes' : 'No'

        f.puts "| #{ssid} | #{security} | #{network} | #{enabled} | #{hidden} | #{guest} |"
      end
    else
      f.puts "*No wireless networks configured*"
    end
    f.puts

    # Connected Clients Summary
    f.puts "## Connected Clients Summary"
    f.puts
    f.puts "### By Connection Type"
    f.puts "- **Wired:** #{data[:client_stats][:wired]}"
    f.puts "- **Wireless:** #{data[:client_stats][:wireless]}"
    f.puts "- **Guest:** #{data[:client_stats][:guests]}"
    f.puts

    f.puts "### By Network"
    data[:client_stats][:by_network].each do |network, clients|
      f.puts "- **#{network}:** #{clients.count} clients"
    end
    f.puts

    # Top 20 Clients by Bandwidth
    f.puts "## Top 20 Clients by Total Bandwidth"
    f.puts
    f.puts "| Hostname | IP | MAC | RX | TX | Total | Connection |"
    f.puts "|----------|-----|-----|-----|-----|-------|------------|"

    top_clients = data[:clients].sort_by { |c| -(c['rx_bytes'].to_i + c['tx_bytes'].to_i) }.first(20)
    top_clients.each do |client|
      hostname = client['hostname'] || client['name'] || 'Unknown'
      ip = client['ip'] || 'N/A'
      mac = client['mac'] || 'N/A'
      rx = format_bytes(client['rx_bytes'])
      tx = format_bytes(client['tx_bytes'])
      total = format_bytes(client['rx_bytes'].to_i + client['tx_bytes'].to_i)
      connection = client['is_wired'] ? 'Wired' : "WiFi (#{client['essid'] || 'N/A'})"

      f.puts "| #{hostname} | #{ip} | #{mac} | #{rx} | #{tx} | #{total} | #{connection} |"
    end
    f.puts

    # Port Forwarding
    f.puts "## Port Forwarding Rules"
    f.puts
    if data[:port_forwards].any?
      f.puts "| Name | Enabled | Protocol | WAN Port | Forward IP | Forward Port |"
      f.puts "|------|---------|----------|----------|------------|--------------|"
      data[:port_forwards].each do |rule|
        name = rule['name'] || 'Unnamed'
        enabled = rule['enabled'] ? '✅' : '❌'
        protocol = rule['proto'] || 'tcp'
        dst_port = rule['dst_port'] || 'N/A'
        fwd = rule['fwd'] || 'N/A'
        fwd_port = rule['fwd_port'] || 'N/A'

        f.puts "| #{name} | #{enabled} | #{protocol} | #{dst_port} | #{fwd} | #{fwd_port} |"
      end
    else
      f.puts "*No port forwarding rules configured*"
    end
    f.puts

    # Firewall Rules Summary
    f.puts "## Firewall Rules Summary"
    f.puts
    if data[:firewall_rules].any?
      f.puts "**Total Rules:** #{data[:firewall_rules].count}"
      f.puts

      by_action = data[:firewall_rules].group_by { |r| r['action'] }
      by_action.each do |action, rules|
        f.puts "- **#{action.upcase}:** #{rules.count} rules"
      end
      f.puts

      f.puts "### Top 10 Firewall Rules"
      f.puts
      f.puts "| Name | Enabled | Action | Protocol | Source | Destination |"
      f.puts "|------|---------|--------|----------|--------|-------------|"

      data[:firewall_rules].first(10).each do |rule|
        name = rule['name'] || 'Unnamed'
        enabled = rule['enabled'] ? '✅' : '❌'
        action = rule['action'] || 'N/A'
        protocol = rule['protocol'] || 'all'
        src = [ rule['src_address'], rule['src_networkconf_type'] ].compact.join(' / ')
        dst = [ rule['dst_address'], rule['dst_networkconf_type'] ].compact.join(' / ')

        src = 'any' if src.empty?
        dst = 'any' if dst.empty?

        f.puts "| #{name} | #{enabled} | #{action} | #{protocol} | #{src} | #{dst} |"
      end
    else
      f.puts "*No firewall rules configured*"
    end
    f.puts

    # Footer
    f.puts "---"
    f.puts
    f.puts "## Notes"
    f.puts
    f.puts "- This inventory was generated automatically via UniFi read-only API"
    f.puts "- Sensitive data (passwords, keys) are not included in this report"
    f.puts "- For detailed client information, see the JSON export"
    f.puts
    f.puts "## Related Documentation"
    f.puts
    f.puts "- [DevOps Assessment](../assessments/devops-assessment.md)"
    f.puts "- [UniFi Security Audit](../assessments/security-audit-unifi-2026-02-18.md)"
    f.puts "- [Network Deployment Strategy](../deployment/deployment-strategy-overview.md)"
    f.puts
    f.puts "**Document Status:** Auto-generated  "
    f.puts "**Next Update:** Monthly or after major network changes"
  end
end

# Main execution
begin
  # Create output directory
  require 'fileutils'
  FileUtils.mkdir_p(OUTPUT_DIR)

  client = UniFiInventoryClient.new(UNIFI_HOST, UNIFI_PORT, UNIFI_API_KEY, UNIFI_USER, UNIFI_PASS, UNIFI_SITE)

  puts "\n" + "─" * 80

  # Collect all data
  system_info = client.get_system_info.first || {}
  devices = client.get_devices
  clients = client.get_clients
  networks = client.get_networks
  port_forwards = client.get_port_forwards
  firewall_groups = client.get_firewall_groups
  firewall_rules = client.get_firewall_rules
  wireless_networks = client.get_wireless_networks
  site_settings = client.get_site_settings

  puts "\n" + "─" * 80
  puts "\n📊 Inventory Summary".bold.blue
  puts "─" * 80

  # Analyze data
  device_stats = categorize_devices(devices)
  client_stats = categorize_clients(clients)

  puts "UniFi Devices: #{device_stats[:total]} (#{device_stats[:online]} online)"
  puts "Connected Clients: #{client_stats[:total]} (#{client_stats[:wired]} wired, #{client_stats[:wireless]} wireless)"
  puts "Networks: #{networks.count}"
  puts "SSIDs: #{wireless_networks.count}"
  puts "Port Forwards: #{port_forwards.count}"
  puts "Firewall Rules: #{firewall_rules.count}"

  # Prepare data structure
  inventory_data = {
    generated_at: Time.now.iso8601,
    system_info: system_info,
    device_stats: device_stats,
    client_stats: client_stats,
    devices: devices,
    clients: clients,
    networks: networks,
    wireless_networks: wireless_networks,
    port_forwards: port_forwards,
    firewall_groups: firewall_groups,
    firewall_rules: firewall_rules,
    site_settings: site_settings
  }

  # Generate outputs
  puts "\n📝 Generating documentation...".blue

  # Markdown
  generate_markdown(inventory_data, MARKDOWN_FILE)
  puts "  ✅ Markdown: #{MARKDOWN_FILE}".green

  # JSON (full data)
  File.write(JSON_FILE, JSON.pretty_generate(inventory_data))
  puts "  ✅ JSON: #{JSON_FILE}".green

  puts "\n" + "=" * 80
  puts "✅ Network inventory complete!".green.bold
  puts "=" * 80

rescue StandardError => e
  puts "\n❌ Error during inventory: #{e.message}".red.bold
  puts e.backtrace.join("\n").yellow if ENV['DEBUG']
  exit 1
end
