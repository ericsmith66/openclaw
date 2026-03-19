#!/usr/bin/env bash
# Source this file to set SmartProxy environment variables
# Usage: source scripts/set_smartproxy_env.sh

export SMART_PROXY_TOKEN=c2708a90c1fde993a6a7cb8bde2a4d1db708b91937ce1e228f6e4ba7b6891ad4
export SMART_PROXY_BASE_URL=http://192.168.4.253:3001
export SMART_PROXY_URL=http://192.168.4.253:3001

echo "✅ SmartProxy environment variables set:"
echo "   SMART_PROXY_TOKEN: ${SMART_PROXY_TOKEN:0:20}..."
echo "   SMART_PROXY_BASE_URL: $SMART_PROXY_BASE_URL"
echo "   SMART_PROXY_URL: $SMART_PROXY_URL"
echo
echo "Now you can run:"
echo "   bin/legion execute --team ROR --agent 'Rails Lead' --prompt 'Hello' --verbose"
