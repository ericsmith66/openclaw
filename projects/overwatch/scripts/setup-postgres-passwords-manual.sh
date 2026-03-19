#!/usr/bin/env bash
#
# Manual PostgreSQL Password Setup (Production)
# Run this on the PRODUCTION server if automated setup fails
#
# Usage:
#   1. Get password from dev machine:
#      security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w
#   2. SSH to production and run this script
#   3. Paste the password when prompted
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PG_USER="nextgen_plaid"
KEYCHAIN_SERVICE="nextgen-plaid-prod-db"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Manual PostgreSQL Password Setup (Production)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Get password from user
echo -e "${YELLOW}→ [1/3] Enter the password${NC}"
echo -e "${BLUE}  Get password from dev machine:${NC}"
echo -e "${BLUE}  security find-generic-password -a 'nextgen_plaid' -s 'nextgen-plaid-prod-db' -w${NC}"
echo ""
read -s -p "Paste password here: " PROD_DB_PASS
echo ""

if [[ -z "${PROD_DB_PASS}" ]]; then
    echo -e "${RED}✗ Password cannot be empty${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Password received${NC}"
echo ""

# Step 2: Set PostgreSQL password
echo -e "${YELLOW}→ [2/3] Setting PostgreSQL password...${NC}"

# Use dollar-quoted string to avoid escaping issues
psql -U ericsmith66 -d postgres <<EOSQL
ALTER USER ${PG_USER} WITH PASSWORD \$\$${PROD_DB_PASS}\$\$;
EOSQL

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ PostgreSQL password set${NC}"
else
    echo -e "${RED}✗ Failed to set PostgreSQL password${NC}"
    exit 1
fi
echo ""

# Step 3: Store in Keychain
echo -e "${YELLOW}→ [3/3] Storing in macOS Keychain...${NC}"

# Delete existing entry if present
security delete-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" 2>/dev/null || true

# Add new password
security add-generic-password -a "${PG_USER}" -s "${KEYCHAIN_SERVICE}" -w "${PROD_DB_PASS}"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Password stored in Keychain${NC}"
else
    echo -e "${RED}✗ Failed to store in Keychain${NC}"
    exit 1
fi
echo ""

# Step 4: Test connection
echo -e "${YELLOW}→ Testing database connection...${NC}"
PGPASSWORD="${PROD_DB_PASS}" psql -U "${PG_USER}" -d postgres -c "SELECT 1;" > /dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo -e "${YELLOW}  Check that user '${PG_USER}' exists and PostgreSQL is running${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Production Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}To retrieve password:${NC}"
echo -e "  security find-generic-password -a '${PG_USER}' -s '${KEYCHAIN_SERVICE}' -w"
echo ""
echo -e "${BLUE}To test connection:${NC}"
echo -e "  PGPASSWORD=\$(security find-generic-password -a '${PG_USER}' -s '${KEYCHAIN_SERVICE}' -w) \\"
echo -e "    psql -U ${PG_USER} -d postgres -c 'SELECT 1;'"
echo ""
