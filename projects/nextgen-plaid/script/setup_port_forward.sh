#!/bin/bash

# Port Forwarding Setup Script for M3 Ultra
# Redirects Port 80 -> 3000
# Requirements: sudo privileges

set -e

ANCHOR_FILE="/etc/pf.anchors/com.nextgen.plaid"
PF_CONF="/etc/pf.conf"
PLIST_FILE="/Library/LaunchDaemons/com.nextgen.pfctl.plist"

echo "--- Setting up Port Forwarding (80 -> 3000) ---"

# 1. Create the PF anchor file
echo "Creating PF anchor file at $ANCHOR_FILE..."
sudo mkdir -p /etc/pf.anchors
# Cover both local and external traffic
# Note: Redirecting to 192.168.4.253 is more reliable for external traffic when ip.forwarding is off
cat <<EOF | sudo tee "$ANCHOR_FILE" > /dev/null
rdr pass on lo0 inet proto tcp from any to any port 80 -> 127.0.0.1 port 3000
rdr pass on en0 inet proto tcp from any to any port 80 -> 192.168.4.253 port 3000
EOF

# 2. Update /etc/pf.conf (Reset and Rebuild to ensure correct order)
echo "Rebuilding $PF_CONF to ensure correct order..."

# We construct a clean pf.conf with the correct order required by macOS:
# options, normalization, queueing, translation, filtering
cat <<EOF | sudo tee "$PF_CONF" > /dev/null
#
# Default PF configuration file.
# Modified by NextGen setup script.
#

# Macros
# (None defined)

# Tables
# (None defined)

# Options
# (None defined)

# Normalization (Scrubbing)
scrub-anchor "com.apple/*"

# Queueing
# (None defined)

# Translation (NAT and RDR)
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
rdr-anchor "com.nextgen.plaid"

# Filtering
dummynet-anchor "com.apple/*"
anchor "com.apple/*"
anchor "com.nextgen.plaid"

# Load Anchors
load anchor "com.apple" from "/etc/pf.anchors/com.apple"
load anchor "com.nextgen.plaid" from "/etc/pf.anchors/com.nextgen.plaid"
EOF

echo "Rebuilt $PF_CONF successfully with correct section ordering."

# 3. Create LaunchDaemon for persistence
echo "Creating LaunchDaemon at $PLIST_FILE..."
cat <<EOF | sudo tee "$PLIST_FILE" > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nextgen.pfctl</string>
    <key>ProgramArguments</key>
    <array>
        <string>/sbin/pfctl</string>
        <string>-e</string>
        <string>-f</string>
        <string>/etc/pf.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/pfctl.err</string>
    <key>StandardOutPath</key>
    <string>/var/log/pfctl.out</string>
</dict>
</plist>
EOF

# 4. Set permissions for LaunchDaemon
sudo chown root:wheel "$PLIST_FILE"
sudo chmod 644 "$PLIST_FILE"

# 5. Load the LaunchDaemon and enable PF
echo "Loading LaunchDaemon and enabling PF..."
sudo launchctl load -w "$PLIST_FILE" || sudo launchctl kickstart -k system/com.nextgen.pfctl

# 6. Final verification
echo "--- Verification ---"
# Redirection rules are in the 'nat' (Network Address Translation) section
sudo pfctl -a com.nextgen.plaid -s nat
echo ""
echo "PF status:"
sudo pfctl -s info | grep "Status"

echo "Done! Port 80 is now forwarded to 3000 and will persist after reboot."
