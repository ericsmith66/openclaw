# BlueBubbles Proxy Activation Guide

**Date:** February 28, 2026  
**Server:** 192.168.4.253 (Nginx reverse proxy)  
**Backend:** 192.168.4.10:1234 (BlueBubbles server)  
**Domain:** blue.higroundsolutions.com

## Overview

Activate the Nginx reverse proxy to forward HTTPS traffic from `blue.higroundsolutions.com` to the BlueBubbles server running on 192.168.4.10:1234.

## Prerequisites

✅ Nginx reverse proxy installed on 192.168.4.253  
✅ BlueBubbles server installed on 192.168.4.10  
✅ Cloudflare DNS A record for `blue.higroundsolutions.com` pointing to public IP (proxied)  
✅ Live configuration ready at `/opt/homebrew/etc/nginx/sites-available/bluebubbles.conf.live`

## Activation Steps

### Step 1: Test Backend Connectivity

SSH to the proxy server and verify BlueBubbles is reachable:

```bash
# SSH to proxy server
ssh <username>@192.168.4.253

# Test BlueBubbles server connectivity
curl -v http://192.168.4.10:1234/api/health

# Expected: Connection successful (may return 404 or auth required - that's OK)
# If connection refused: BlueBubbles server is not running
```

### Step 2: Activate Live Configuration

```bash
# Navigate to Nginx config directory
cd /opt/homebrew/etc/nginx/sites-available

# Backup current coming-soon config
sudo cp bluebubbles.conf bluebubbles.conf.backup-$(date +%Y%m%d-%H%M%S)

# Activate live proxy configuration
sudo cp bluebubbles.conf.live bluebubbles.conf

# Verify the change
diff bluebubbles.conf.backup-* bluebubbles.conf
```

### Step 3: Test and Reload Nginx

```bash
# Test Nginx configuration
sudo nginx -t

# Expected output:
# nginx: the configuration file /opt/homebrew/etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /opt/homebrew/etc/nginx/nginx.conf test is successful

# Reload Nginx (zero-downtime)
sudo nginx -s reload

# Verify Nginx reloaded successfully
echo "✅ Nginx reload completed"
```

### Step 4: Verify Proxy is Working

```bash
# Test from proxy server (local test)
curl -k -I https://localhost/api/health -H 'Host: blue.higroundsolutions.com'

# Expected: 200 OK or auth required (depends on BlueBubbles config)
# If 502 Bad Gateway: Backend not reachable
# If 503: Still using coming-soon config
```

### Step 5: Test External Access

From your development machine or any internet-connected device:

```bash
# Test external HTTPS access
curl -I https://blue.higroundsolutions.com/api/health

# Expected: 200 OK or auth required
# Response headers should include Cloudflare headers (cf-ray, cf-cache-status)
```

### Step 6: Monitor Logs

```bash
# On 192.168.4.253, monitor logs
sudo tail -f /opt/homebrew/var/log/nginx/bluebubbles-access.log
sudo tail -f /opt/homebrew/var/log/nginx/error.log

# Watch for incoming requests and any errors
```

## Verification Checklist

- [ ] Backend connectivity confirmed (`curl http://192.168.4.10:1234/api/health`)
- [ ] Live config activated (`bluebubbles.conf.live` → `bluebubbles.conf`)
- [ ] Nginx test passed (`nginx -t`)
- [ ] Nginx reloaded successfully (`nginx -s reload`)
- [ ] Local HTTPS test successful (from 192.168.4.253)
- [ ] External HTTPS test successful (from internet)
- [ ] No errors in Nginx error log
- [ ] Access log shows incoming requests

## Troubleshooting

### Issue: 502 Bad Gateway

**Cause:** Nginx cannot connect to BlueBubbles backend at 192.168.4.10:1234

**Solutions:**
```bash
# Verify BlueBubbles is running on 192.168.4.10
ssh <username>@192.168.4.10
netstat -an | grep 1234  # Should show LISTEN

# Test connectivity from proxy server
curl http://192.168.4.10:1234/api/health

# Check firewall rules on 192.168.4.10 (unlikely on macOS)
```

### Issue: 503 Service Unavailable

**Cause:** Still using coming-soon config

**Solutions:**
```bash
# Verify correct config is active
cat /opt/homebrew/etc/nginx/sites-available/bluebubbles.conf | grep "proxy_pass"

# Should show: proxy_pass http://bluebubbles;
# If not present, copy .live config again and reload
```

### Issue: Connection Timeout

**Cause:** Network connectivity issue between proxy and backend

**Solutions:**
```bash
# Ping backend
ping 192.168.4.10

# Check routing
traceroute 192.168.4.10

# Verify both machines on same network segment
```

## Rollback Procedure

If issues occur, revert to coming-soon page:

```bash
# SSH to 192.168.4.253
ssh <username>@192.168.4.253

# Restore backup
sudo cp /opt/homebrew/etc/nginx/sites-available/bluebubbles.conf.backup-* \
        /opt/homebrew/etc/nginx/sites-available/bluebubbles.conf

# Test and reload
sudo nginx -t && sudo nginx -s reload

# Verify rollback
curl -I https://blue.higroundsolutions.com/
# Should return 200 with coming-soon page
```

## Next Steps

After proxy activation:

1. **Configure BlueBubbles Server** with Dynamic DNS/Custom URL
   - Proxy Setup: "Dynamic DNS / Custom URL"
   - Address: `https://blue.higroundsolutions.com`
   - Set strong server password

2. **Test WebSocket Connectivity** for real-time messaging

3. **Configure BlueBubbles Client** apps with server URL and password

4. **Monitor Performance** and adjust rate limits if needed

## Related Documentation

- [BlueBubbles Deployment Guide](../knowledge_base/deployment-bluebubbles.md)
- [BlueBubbles Runbook](../knowledge_base/runbook-bluebubbles.md)
- [Reverse Proxy README](../../highground-rev-proxy/README.md)
