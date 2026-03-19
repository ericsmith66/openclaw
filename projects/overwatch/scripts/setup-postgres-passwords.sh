#!/usr/bin/env bash
#
# PostgreSQL Password Setup Script
# Sets up secure passwords for nextgen_plaid PostgreSQL user
# Stores passwords in macOS Keychain for secure access
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROD_HOST="192.168.4.253"
PROD_USER="ericsmith66"
PG_USER="nextgen_plaid"
KEYCHAIN_SERVICE="nextgen-plaid-prod-db"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PostgreSQL Password Setup for nextgen-plaid${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Generate secure password
echo -e "${YELLOW}→ [1/5] Generating secure password...${NC}"
PROD_DB_PASS=$(openssl rand -base64 32)
echo -e "${GREEN}✓ Generated 32-character password${NC}"
echo ""

# Step 2: Set password on local PostgreSQL (for production user testing)
echo -e "${YELLOW}→ [2/5] Setting password for local PostgreSQL user '${PG_USER}'...${NC}"
psql -U ericsmith66 -d postgres -c "ALTER USER ${PG_USER} WITH PASSWORD '${PROD_DB_PASS}';" > /dev/null 2>&1 || {
    echo -e "${RED}✗ Failed to set local PostgreSQL password${NC}"
    echo -e "${RED}  Make sure PostgreSQL is running and user '${PG_USER}' exists${NC}"
    exit 1
}
echo -e "${GREEN}✓ Local password set successfully${NC}"
echo ""

# Step 3: Store password in local Keychain
echo -e "${YELLOW}→ [3/5] Storing password in local macOS Keychain...${NC}"
# Delete existing entry if present
security delete-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" 2>/dev/null || true
# Add new password
security add-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" -w "${PROD_DB_PASS}"
echo -e "${GREEN}✓ Password stored in Keychain (service: ${KEYCHAIN_SERVICE})${NC}"
echo ""

# Step 4: Test local password retrieval
echo -e "${YELLOW}→ [4/5] Testing local Keychain access...${NC}"
TEST_PASS=$(security find-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" -w 2>/dev/null)
if [[ "${TEST_PASS}" == "${PROD_DB_PASS}" ]]; then
    echo -e "${GREEN}✓ Password retrieved successfully from Keychain${NC}"
else
    echo -e "${RED}✗ Password mismatch in Keychain${NC}"
    exit 1
fi
echo ""

# Step 5: Setup production server
echo -e "${YELLOW}→ [5/5] Setting up production server (${PROD_HOST})...${NC}"
echo -e "${BLUE}  This will:${NC}"
echo -e "${BLUE}  - Set PostgreSQL password for '${PG_USER}' user${NC}"
echo -e "${BLUE}  - Store password in production Keychain${NC}"
echo -e "${BLUE}  - Test database connectivity${NC}"
echo ""
read -p "Continue with production setup? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Test SSH connection first
    echo -e "${BLUE}  Testing SSH connection...${NC}"
    if ! ssh -o ConnectTimeout=10 "${PROD_USER}@${PROD_HOST}" "echo 'SSH OK'" > /dev/null 2>&1; then
        echo -e "${RED}✗ Cannot connect to production server${NC}"
        echo -e "${RED}  Check SSH connectivity to ${PROD_HOST}${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ SSH connection successful${NC}"
    
    # Create remote setup script (password passed via stdin to avoid escaping issues)
    REMOTE_SCRIPT='#!/usr/bin/env bash
set -euo pipefail

# Read password from stdin
read -r PROD_DB_PASS

PG_USER="nextgen_plaid"
KEYCHAIN_SERVICE="nextgen-plaid-prod-db"

# Set PostgreSQL password (use dollar-quoted string to avoid escaping issues)
echo "Setting PostgreSQL password..."
psql -U ericsmith66 -d postgres <<EOSQL
ALTER USER ${PG_USER} WITH PASSWORD \$\${PROD_DB_PASS}\$\$;
EOSQL

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to set PostgreSQL password"
    exit 1
fi

# Store in Keychain
echo "Storing in Keychain..."
security delete-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" 2>/dev/null || true
security add-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" -w "${PROD_DB_PASS}"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to store in Keychain"
    exit 1
fi

# Test connection
echo "Testing database connection..."
PGPASSWORD="${PROD_DB_PASS}" psql -U "${PG_USER}" -d postgres -c "SELECT 1;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Database connection test failed"
    exit 1
fi

echo "SUCCESS"
'

    # Execute on production server (password passed via stdin)
    RESULT=$(echo "${PROD_DB_PASS}" | ssh "${PROD_USER}@${PROD_HOST}" "bash -s" <<< "${REMOTE_SCRIPT}" 2>&1) || {
        echo -e "${RED}✗ Production setup failed${NC}"
        echo -e "${RED}  Error: ${RESULT}${NC}"
        echo ""
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo -e "${YELLOW}  1. Verify PostgreSQL is running on production${NC}"
        echo -e "${YELLOW}  2. Verify user 'nextgen_plaid' exists: ssh ${PROD_USER}@${PROD_HOST} 'psql -U ericsmith66 -d postgres -c \"\\du\"'${NC}"
        echo -e "${YELLOW}  3. Try manual setup (see DEPLOYMENT_SETUP.md)${NC}"
        exit 1
    }

    if [[ "${RESULT}" == *"SUCCESS"* ]]; then
        echo -e "${GREEN}✓ Production server configured successfully${NC}"
    else
        echo -e "${RED}✗ Production setup encountered issues${NC}"
        echo -e "${RED}  Output: ${RESULT}${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Skipping production setup${NC}"
    echo -e "${YELLOW}  Run this script again to configure production${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  PostgreSQL Password Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Password generated (32 characters)"
echo -e "  ${GREEN}✓${NC} Local PostgreSQL user '${PG_USER}' password set"
echo -e "  ${GREEN}✓${NC} Password stored in local Keychain"
echo -e "  ${GREEN}✓${NC} Keychain access verified"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "  ${GREEN}✓${NC} Production server configured"
fi
echo ""
echo -e "${BLUE}To retrieve password:${NC}"
echo -e "  security find-generic-password -a '${PG_USER}' -s '${KEYCHAIN_SERVICE}' -w"
echo ""
echo -e "${BLUE}To test database connection:${NC}"
echo -e "  PGPASSWORD=\$(security find-generic-password -a '${PG_USER}' -s '${KEYCHAIN_SERVICE}' -w) \\"
echo -e "    psql -U ${PG_USER} -d postgres -c 'SELECT 1;'"
echo ""
