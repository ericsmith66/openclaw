#!/bin/bash
# Activate BlueBubbles proxy on 192.168.4.253
# Run this script from your local machine

set -e

echo "🔵 Activating BlueBubbles Proxy"
echo "================================"
echo ""

# Step 1: Copy live config to server
echo "📤 Copying live config to 192.168.4.253..."
scp nginx/sites-available/bluebubbles.conf.live ericsmith66@192.168.4.253:/tmp/

echo "✅ File copied to /tmp/bluebubbles.conf.live"
echo ""
echo "⚠️  Now SSH to the server and run these commands:"
echo ""
echo "    ssh ericsmith66@192.168.4.253"
echo ""
echo "    sudo cp /tmp/bluebubbles.conf.live /opt/homebrew/etc/nginx/sites-available/bluebubbles.conf"
echo "    sudo nginx -s reload"
echo "    curl -k -I https://localhost/api/health -H 'Host: blue.higroundsolutions.com'"
echo ""
echo "Expected result: Should get a response from BlueBubbles (may be 404 or 401)"
