# UniFi API Ruby Clients & Tools
**Updated:** February 19, 2026  
**Target:** UDM-SE at 192.168.4.1  
**Firmware:** 4.4.6 / UniFi Network 8.4.6

---

## Overview

The UniFi Ruby ecosystem is **small and mostly unmaintained** as of 2026. Most gems target controller versions 4.x–5.x (2017–2020 era) and may require adjustments for modern UniFi OS, particularly:
- Base path changes: `/proxy/network/api/s/default/`
- Cookie/session handling
- Authentication endpoint: `/api/auth/login` (vs legacy `/api/login`)

⚠️ **Reality Check:** No actively maintained "best" gem exists. Expect to fork, patch, or build custom solutions.

---

## Ruby Gem Landscape

### 1. davisonja/unifi-gem ⭐⭐⭐ **RECOMMENDED**

**GitHub:** https://github.com/davisonja/unifi-gem  
**Installation:** Not on RubyGems (use GitHub source)

```ruby
# Gemfile
gem 'unifi', github: 'davisonja/unifi-gem'
```

**Target:** Controller 5.x.x (closer to modern than v4-only gems)  
**Architecture:** Ruby port inspired by PHP Art-of-WiFi/UniFi-API-client

**Pros:**
- Most comprehensive method coverage
- Structured interface mirroring common endpoints
- Good starting point for read-only monitoring
- Well-architected (OOP design)

**Cons:**
- Last major activity 2019–2020
- Not published to RubyGems
- Requires testing on UDM-SE (URL/port adjustments likely needed)

**Usage Example:**
```ruby
require 'unifi'

client = Unifi::Client.new(
  host: '192.168.4.1',
  port: 443,
  site: 'default',
  username: ENV['UNIFI_USER'],
  password: ENV['UNIFI_PASS']
)

# Get devices
devices = client.list_devices
devices.each do |device|
  puts "#{device['name']} - #{device['type']} - #{device['state']}"
end

# Get active clients
clients = client.list_clients
puts "Active clients: #{clients.count}"

# Get site health
health = client.stat_health
puts health.inspect
```

**Known Issues:**
- May need base URI adjustment for UDM-SE `/proxy/network` prefix
- Authentication endpoint might be `/api/auth/login` vs `/api/login`

**Recommendation:** Fork this gem and patch for UDM-SE if needed.

---

### 2. collectiveidea/unifi ⭐⭐

**GitHub:** https://github.com/collectiveidea/unifi  
**RubyGems:** `gem install unifi`  
**Published:** Yes (easy install)

**Target:** Controller v4 explicitly  
**Architecture:** Simple, lightweight client

**Pros:**
- Published gem (easy installation)
- Straightforward setup
- Minimal dependencies

**Cons:**
- Explicitly v4-only (may break on modern paths/auth)
- Very old (last update ~2017)
- Limited method coverage

**Usage Example:**
```ruby
require 'unifi'

controller = Unifi::Controller.new(
  host: '192.168.4.1',
  username: ENV['UNIFI_USER'],
  password: ENV['UNIFI_PASS']
)

devices = controller.devices
clients = controller.clients
```

**Compatibility Warning:** Likely requires significant patching for UDM-SE.

---

### 3. hculap/unifi-api ⭐

**GitHub:** https://github.com/hculap/unifi-api  
**RubyGems:** `gem install unifi-api`  
**Published:** Yes

**Target:** Older Python client port  
**Focus:** Core API interactions (login, get APs)

**Pros:**
- Published gem
- Simple and direct

**Cons:**
- Even older base than others
- Limited scope
- Minimal documentation

**Usage Example:**
```ruby
require 'unifi-api'

client = UnifiApi::Client.new(
  host: '192.168.4.1',
  username: ENV['UNIFI_USER'],
  password: ENV['UNIFI_PASS']
)

aps = client.get_aps
```

**Recommendation:** Avoid unless you need something extremely minimal.

---

### 4. aetaric/unifi-api ⭐⭐ **UniFi OS Focused**

**GitHub:** https://github.com/aetaric/unifi-api  
**Installation:** Build from source (not on RubyGems)

**Target:** UniFi OS API (modern console-level)  
**Focus:** Alerts, IPS/IDS, events on UDM-SE

**Pros:**
- Tailored to newer UniFi OS quirks
- Good for alert/event monitoring
- Focuses on security events

**Cons:**
- Incomplete/in-progress
- Narrow focus (not full Network stats/clients)
- Not published

**Use Case:** If you're specifically focused on alerts/IPS events rather than full network stats.

---

## UniFi Protect (Cameras)

### jeremycole/unifi_protect ⭐⭐⭐

**GitHub:** https://github.com/jeremycole/unifi_protect  
**RubyGems:** `gem install unifi_protect`  
**Published:** Yes

**Target:** UniFi Protect API (cameras)  
**Scope:** Separate from Network API

**Capabilities:**
- Camera status and configuration
- Snapshot retrieval
- Video export
- Motion detection events
- Recording management

**Usage Example:**
```ruby
require 'unifi_protect'

protect = UnifiProtect::Client.new(
  host: '192.168.4.1',
  username: ENV['UNIFI_USER'],
  password: ENV['UNIFI_PASS']
)

# Get all cameras
cameras = protect.cameras

# Get snapshot from camera
snapshot = protect.snapshot(camera_id: 'abc123')
File.write('snapshot.jpg', snapshot)

# Get motion events
events = protect.motion_events(start: 1.hour.ago)
```

**Recommendation:** Use this for any camera-related operations on UDM-SE.

---

## Custom Lightweight Client (RECOMMENDED) ⭐⭐⭐

Given the state of existing gems, **rolling your own lightweight client** is often the most reliable approach.

### HTTParty-Based Client

```ruby
require 'httparty'
require 'json'

class UniFiClient
  include HTTParty
  base_uri 'https://192.168.4.1'  # Your UDM-SE IP
  headers 'Accept' => 'application/json'
  
  # Disable SSL verification for self-signed cert (use carefully)
  default_options.update(verify: false)
  
  def initialize(username, password, site: 'default')
    @site = site
    @cookies = login(username, password)
    raise 'Authentication failed' unless @cookies
  end
  
  def login(username, password)
    response = self.class.post('/api/auth/login',
      body: { 
        username: username, 
        password: password, 
        remember: true 
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    
    if response.success?
      # Extract cookies from response
      response.headers['set-cookie']
    else
      nil
    end
  end
  
  # READ OPERATIONS
  
  def system_info
    get('/proxy/network/api/s/default/stat/sysinfo')
  end
  
  def devices
    get('/proxy/network/api/s/default/stat/device')
  end
  
  def clients
    get('/proxy/network/api/s/default/stat/sta')
  end
  
  def networks
    get('/proxy/network/api/s/default/rest/networkconf')
  end
  
  def wireless_networks
    get('/proxy/network/api/s/default/rest/wlanconf')
  end
  
  def port_forwards
    get('/proxy/network/api/s/default/rest/portforward')
  end
  
  def firewall_rules
    get('/proxy/network/api/s/default/rest/firewallrule')
  end
  
  def site_health
    get('/proxy/network/api/s/default/stat/health')
  end
  
  def events(limit: 100)
    get('/proxy/network/api/s/default/stat/event', query: { _limit: limit })
  end
  
  # WRITE OPERATIONS
  
  def block_client(mac)
    cmd('stamgr', 'block-sta', { mac: mac })
  end
  
  def unblock_client(mac)
    cmd('stamgr', 'unblock-sta', { mac: mac })
  end
  
  def kick_client(mac)
    cmd('stamgr', 'kick-sta', { mac: mac })
  end
  
  def restart_device(mac)
    cmd('devmgr', 'restart', { mac: mac })
  end
  
  def adopt_device(mac)
    cmd('devmgr', 'adopt', { mac: mac })
  end
  
  def speedtest
    cmd('devmgr', 'speedtest')
  end
  
  def speedtest_status
    cmd('devmgr', 'speedtest-status')
  end
  
  def enable_port_forward(rule_id)
    put("/proxy/network/api/s/default/rest/portforward/#{rule_id}", 
        { enabled: true })
  end
  
  def disable_port_forward(rule_id)
    put("/proxy/network/api/s/default/rest/portforward/#{rule_id}", 
        { enabled: false })
  end
  
  def create_network(config)
    post('/proxy/network/api/s/default/rest/networkconf', config)
  end
  
  def update_network(network_id, config)
    put("/proxy/network/api/s/default/rest/networkconf/#{network_id}", config)
  end
  
  def create_firewall_rule(config)
    post('/proxy/network/api/s/default/rest/firewallrule', config)
  end
  
  private
  
  def get(path, query: {})
    response = self.class.get(path, 
      cookies: @cookies,
      query: query
    )
    parse_response(response)
  end
  
  def post(path, body)
    response = self.class.post(path,
      body: body.to_json,
      cookies: @cookies,
      headers: { 'Content-Type' => 'application/json' }
    )
    parse_response(response)
  end
  
  def put(path, body)
    response = self.class.put(path,
      body: body.to_json,
      cookies: @cookies,
      headers: { 'Content-Type' => 'application/json' }
    )
    parse_response(response)
  end
  
  def cmd(manager, command, params = {})
    body = { cmd: command }.merge(params)
    post("/proxy/network/api/s/#{@site}/cmd/#{manager}", body)
  end
  
  def parse_response(response)
    return nil unless response.success?
    
    data = JSON.parse(response.body)
    
    # UniFi API wraps responses in { data: [...], meta: { rc: "ok" } }
    if data['meta'] && data['meta']['rc'] == 'ok'
      data['data']
    else
      raise "API Error: #{data['meta']['msg']}" if data['meta']
      nil
    end
  rescue JSON::ParserError
    nil
  end
end
```

### Usage Examples

```ruby
# Initialize client
client = UniFiClient.new(
  ENV['UNIFI_USER'],
  ENV['UNIFI_PASS']
)

# Read operations
devices = client.devices
puts "Total devices: #{devices.count}"

clients = client.clients
online_clients = clients.select { |c| c['last_seen'] > Time.now.to_i - 300 }
puts "Online clients: #{online_clients.count}"

health = client.site_health
puts "Health: #{health.inspect}"

# Write operations (be careful!)
# client.block_client('aa:bb:cc:dd:ee:ff')
# client.restart_device('11:22:33:44:55:66')
# client.disable_port_forward('rule_id_here')
```

### Faraday-Based Alternative

```ruby
require 'faraday'
require 'json'

class UniFiClient
  def initialize(host, username, password, site: 'default')
    @host = host
    @site = site
    @conn = Faraday.new(url: "https://#{host}") do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      f.ssl[:verify] = false  # Self-signed cert
    end
    
    login(username, password)
  end
  
  def login(username, password)
    response = @conn.post('/api/auth/login') do |req|
      req.body = {
        username: username,
        password: password,
        remember: true
      }
    end
    
    @cookies = response.headers['set-cookie']
    raise 'Login failed' unless @cookies
  end
  
  def get(path)
    response = @conn.get(path) do |req|
      req.headers['Cookie'] = @cookies
    end
    
    response.body['data'] if response.body['meta']['rc'] == 'ok'
  end
  
  # Add methods as needed...
end
```

---

## Cloud API (Site Manager)

**No Ruby gem exists** for the UniFi Cloud API. Wrap it with HTTParty or Faraday.

### Cloud API Client

```ruby
class UniFiCloudClient
  include HTTParty
  base_uri 'https://api.ui.com'
  
  def initialize(api_key)
    @api_key = api_key
  end
  
  def headers
    {
      'X-API-KEY' => @api_key,
      'Accept' => 'application/json'
    }
  end
  
  def hosts
    self.class.get('/ea/hosts', headers: headers)
  end
  
  def sites
    self.class.get('/v1/sites', headers: headers)
  end
  
  def devices
    self.class.get('/v1/devices', headers: headers)
  end
  
  def isp_metrics(site_id, start_time, end_time)
    self.class.get('/v1/isp-metrics', 
      headers: headers,
      query: {
        site_id: site_id,
        start: start_time.to_i,
        end: end_time.to_i
      }
    )
  end
end

# Usage
cloud = UniFiCloudClient.new(ENV['UNIFI_CLOUD_API_KEY'])
hosts = cloud.hosts
puts "Controllers: #{hosts.count}"
```

---

## Recommendations by Use Case

### Read-Only Monitoring ⭐⭐⭐
**Best:** Custom HTTParty client (full control, maintainable)  
**Alternative:** Fork davisonja/unifi-gem and patch for UDM-SE

### Security Automation (Block/Kick Clients) ⭐⭐⭐
**Best:** Custom HTTParty client with write methods  
**Why:** Full control over error handling and retry logic

### Camera Integration ⭐⭐⭐
**Best:** jeremycole/unifi_protect gem (published, works well)  
**Why:** Dedicated Protect API support

### Network Configuration Automation ⭐⭐⭐
**Best:** Custom client (complex configs need precise control)  
**Consider:** Infrastructure as Code tools (Terraform provider exists)

### Event Monitoring & Alerting ⭐⭐
**Best:** Custom HTTParty client  
**Alternative:** aetaric/unifi-api if focused on IPS/alerts

### Rails Integration ⭐⭐⭐
**Best:** Custom client wrapped as a service object  
**Pattern:** `app/services/unifi_client.rb` with caching/error handling

---

## Best Practices

### 1. Environment Variables
```bash
# .env
UNIFI_HOST=192.168.4.1
UNIFI_PORT=443
UNIFI_SITE=default
UNIFI_USER=readonly_admin
UNIFI_PASS=secure_password
UNIFI_CLOUD_API_KEY=your_cloud_key
```

### 2. Error Handling
```ruby
class UniFiClient
  class AuthenticationError < StandardError; end
  class APIError < StandardError; end
  
  def safe_request
    yield
  rescue Faraday::Error => e
    raise APIError, "Network error: #{e.message}"
  rescue JSON::ParserError => e
    raise APIError, "Invalid JSON response: #{e.message}"
  end
end
```

### 3. Caching (Rails)
```ruby
class UniFiService
  def devices
    Rails.cache.fetch('unifi_devices', expires_in: 5.minutes) do
      @client.devices
    end
  end
end
```

### 4. Background Jobs
```ruby
class UniFiHealthCheckJob < ApplicationJob
  queue_as :monitoring
  
  def perform
    client = UniFiClient.new(ENV['UNIFI_USER'], ENV['UNIFI_PASS'])
    health = client.site_health
    
    if health.any? { |h| h['status'] != 'ok' }
      NotificationMailer.network_alert(health).deliver_later
    end
  end
end
```

### 5. Testing with VCR
```ruby
# spec/spec_helper.rb
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('<UNIFI_PASSWORD>') { ENV['UNIFI_PASS'] }
end

# spec/services/unifi_client_spec.rb
RSpec.describe UniFiClient do
  it 'fetches devices' do
    VCR.use_cassette('unifi_devices') do
      client = UniFiClient.new('user', 'pass')
      expect(client.devices).to be_an(Array)
    end
  end
end
```

---

## SSL Certificate Handling

UniFi controllers use self-signed certificates by default.

### Option 1: Disable Verification (Development Only)
```ruby
HTTParty.get(url, verify: false)
```

### Option 2: Trust Certificate
```bash
# Export cert from browser or controller
openssl s_client -connect 192.168.4.1:443 -showcerts > unifi.crt

# Use in Ruby
HTTParty.get(url, ssl_ca_file: '/path/to/unifi.crt')
```

### Option 3: Custom Domain with Let's Encrypt
Configure your UDM-SE with a proper domain and Let's Encrypt certificate.

---

## Performance Considerations

### Rate Limiting
```ruby
class UniFiClient
  RATE_LIMIT = 1.0  # seconds between requests
  
  def initialize(*)
    super
    @last_request_time = nil
  end
  
  private
  
  def get(path)
    enforce_rate_limit
    super
  end
  
  def enforce_rate_limit
    if @last_request_time
      elapsed = Time.now - @last_request_time
      sleep(RATE_LIMIT - elapsed) if elapsed < RATE_LIMIT
    end
    @last_request_time = Time.now
  end
end
```

### Connection Pooling
```ruby
class UniFiClient
  def self.pool
    @pool ||= ConnectionPool.new(size: 5, timeout: 5) do
      new(ENV['UNIFI_USER'], ENV['UNIFI_PASS'])
    end
  end
end

# Usage
UniFiClient.pool.with do |client|
  devices = client.devices
end
```

---

## Related Documentation

- [UniFi API Read-Only Data Catalog](./unifi-api-data-catalog.md)
- [UniFi API Write Capabilities](./unifi-api-write-capabilities.md)
- [Network Inventory Script](../../scripts/unifi-network-inventory.rb)
- [Security Audit Script](../../scripts/unifi-security-audit.rb)

---

**Document Status:** Reference  
**Last Updated:** 2026-02-19  
**Maintainer:** AiderDesk  
**Ruby Version:** 3.x compatible
