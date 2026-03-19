#!/bin/bash
# Quick SSH login to UDM-SE
# Usage: ./scripts/ssh-udm.sh

UDM_HOST="192.168.4.1"
UDM_USER="root"  # Default user for UDM-SE SSH

echo "🔐 Connecting to UDM-SE at ${UDM_HOST}..."
echo ""
echo "Note: If SSH is not enabled, you'll need to enable it in UniFi OS Console:"
echo "  Settings → Console Settings → Advanced → SSH"
echo ""

ssh ${UDM_USER}@${UDM_HOST}
