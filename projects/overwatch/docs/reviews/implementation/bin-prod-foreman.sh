#!/usr/bin/env bash
#
# Production Launcher for nextgen-plaid
# Purpose: Start application with secrets from macOS Keychain
# Usage: bin/prod
#
# PHASE 1: Uses Foreman for process management (temporary)
# PHASE 2: Will migrate to launchd supervision (future)
#
# Changes from original:
# - Added rbenv initialization (lines 27-33)
# - Added PATH validation (lines 42-52)
# - Fixed database check to use nextgen_plaid_production (line 87)
# - Added Foreman process management (lines 119-136)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service prefix for keychain
SERVICE_PREFIX="nextgen-plaid"

# Change to app directory
cd "$(dirname "$0")/.."

# Initialize rbenv for correct Ruby version
if [ -f ~/.zprofile ]; then
    source ~/.zprofile
fi
if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  nextgen-plaid - Production Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Ruby Version:${NC} $(ruby -v)"
echo ""

# Verify required system dependencies
echo -e "${YELLOW}→ Verifying system dependencies...${NC}"

if ! command -v psql >/dev/null 2>&1; then
    echo -e "${RED}✗ psql command not found${NC}" >&2
    echo -e "${RED}  Ensure PostgreSQL client is installed${NC}" >&2
    echo -e "${YELLOW}  Try: brew install postgresql@16${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✓ System dependencies verified${NC}"
echo ""

# Function to get secret from Keychain
get_secret() {
    local key=$1
    local service="${SERVICE_PREFIX}-${key}"
    local account="${SERVICE_PREFIX}"
    
    security find-generic-password -a "${account}" -s "${service}" -w 2>/dev/null || {
        echo -e "${RED}✗ Failed to retrieve secret: ${key}${NC}" >&2
        echo -e "${RED}  Run './scripts/setup-keychain.sh' to configure secrets${NC}" >&2
        exit 1
    }
}

# Load secrets from Keychain
echo -e "${YELLOW}→ Loading secrets from Keychain...${NC}"

export RAILS_ENV=production
export NEXTGEN_PLAID_DATABASE_PASSWORD=$(get_secret "DATABASE_PASSWORD")
export PLAID_CLIENT_ID=$(get_secret "PLAID_CLIENT_ID")
export PLAID_SECRET=$(get_secret "PLAID_SECRET")
export CLAUDE_API_KEY=$(get_secret "CLAUDE_API_KEY")
export RAILS_MASTER_KEY=$(get_secret "RAILS_MASTER_KEY")

# Optional secrets (don't fail if missing)
export REDIS_PASSWORD=$(security find-generic-password -a "${SERVICE_PREFIX}" -s "${SERVICE_PREFIX}-REDIS_PASSWORD" -w 2>/dev/null || echo "")
export SENTRY_DSN=$(security find-generic-password -a "${SERVICE_PREFIX}" -s "${SERVICE_PREFIX}-SENTRY_DSN" -w 2>/dev/null || echo "")

echo -e "${GREEN}✓ Secrets loaded successfully${NC}"
echo ""

# Verify database connectivity
echo -e "${YELLOW}→ Verifying database connectivity...${NC}"
if PGPASSWORD="${NEXTGEN_PLAID_DATABASE_PASSWORD}" psql -U nextgen_plaid -d nextgen_plaid_production -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection verified${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo -e "${RED}  Check PostgreSQL is running and password is correct${NC}"
    exit 1
fi
echo ""

# Check if database exists and is up to date
echo -e "${YELLOW}→ Checking database status...${NC}"
if bin/rails db:version > /dev/null 2>&1; then
    CURRENT_VERSION=$(bin/rails db:version 2>/dev/null | grep "Current version:" | awk '{print $3}')
    echo -e "${GREEN}✓ Database ready (migration version: ${CURRENT_VERSION:-unknown})${NC}"
else
    echo -e "${YELLOW}⚠ Database may need setup or migrations${NC}"
    echo -e "${YELLOW}  Run: RAILS_ENV=production bin/rails db:migrate${NC}"
fi
echo ""

# Display startup info
echo -e "${BLUE}Environment:${NC}"
echo -e "  RAILS_ENV:     ${RAILS_ENV}"
echo -e "  Ruby Version:  $(ruby -v | awk '{print $2}')"
echo -e "  Database:      nextgen_plaid_production"
echo -e "  Queue:         nextgen_plaid_production_queue"
echo -e "  Cable:         nextgen_plaid_production_cable"
echo ""

# Install foreman if needed
if ! gem list foreman -i --silent; then
    echo -e "${YELLOW}Installing foreman gem...${NC}"
    gem install foreman
    echo ""
fi

export PORT=3000

# Start services via Foreman
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Starting services via Foreman...${NC}"
echo -e "${BLUE}  - Web server (Puma) on port 3000${NC}"
echo -e "${BLUE}  - Background workers (SolidQueue)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Note: This is Phase 1 (Foreman). Will migrate to launchd in Phase 2.${NC}"
echo ""

exec foreman start -f Procfile.prod "$@"
