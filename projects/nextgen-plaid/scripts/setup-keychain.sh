#!/usr/bin/env bash
#
# Keychain Setup Script for nextgen-plaid
# Purpose: Securely store all application secrets in macOS Keychain
# Usage: ./scripts/setup-keychain.sh
#

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service prefix for keychain entries
SERVICE_PREFIX="nextgen-plaid"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Keychain Setup - nextgen-plaid${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}This script will securely store application secrets${NC}"
echo -e "${BLUE}in macOS Keychain for production use.${NC}"
echo ""

# Function to validate secret strength (basic validation)
validate_secret() {
    local secret="$1"
    local min_length="$2"
    
    if [[ ${#secret} -lt ${min_length} ]]; then
        return 1
    fi
    
    return 0
}

# Function to store secret in Keychain
store_secret() {
    local key="$1"
    local value="$2"
    local service="${SERVICE_PREFIX}-${key}"
    local account="${SERVICE_PREFIX}"
    
    # Delete existing entry if present
    security delete-generic-password -a "${account}" -s "${service}" 2>/dev/null || true
    
    # Add new secret
    security add-generic-password -a "${account}" -s "${service}" -w "${value}"
    
    echo -e "${GREEN}✓ Stored: ${key}${NC}"
}

# Function to test secret retrieval
test_secret() {
    local key="$1"
    local service="${SERVICE_PREFIX}-${key}"
    local account="${SERVICE_PREFIX}"
    
    if security find-generic-password -a "${account}" -s "${service}" -w > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to prompt for secret
prompt_secret() {
    local key="$1"
    local description="$2"
    local min_length="$3"
    local is_optional="$4"
    
    echo ""
    echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}Setting up: ${key}${NC}"
    echo -e "${BLUE}Description: ${description}${NC}"
    
    if [[ "${is_optional}" == "true" ]]; then
        echo -e "${YELLOW}(Optional - press Enter to skip)${NC}"
    else
        echo -e "${YELLOW}(Required - minimum ${min_length} characters)${NC}"
    fi
    
    # Check if secret already exists
    if test_secret "${key}"; then
        echo -e "${GREEN}ℹ Current value exists in Keychain${NC}"
        read -p "Update existing value? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}⊙ Skipped (keeping existing value)${NC}"
            return 0
        fi
    fi
    
    # Prompt for secret (hidden input)
    while true; do
        read -s -p "Enter ${key}: " secret
        echo ""
        
        # Allow empty for optional secrets
        if [[ -z "${secret}" ]] && [[ "${is_optional}" == "true" ]]; then
            echo -e "${YELLOW}⊙ Skipped (optional)${NC}"
            return 0
        fi
        
        # Validate secret
        if ! validate_secret "${secret}" "${min_length}"; then
            echo -e "${RED}✗ Secret too short (minimum ${min_length} characters)${NC}"
            continue
        fi
        
        # Confirm secret
        read -s -p "Confirm ${key}: " confirm
        echo ""
        
        if [[ "${secret}" != "${confirm}" ]]; then
            echo -e "${RED}✗ Secrets do not match. Please try again.${NC}"
            continue
        fi
        
        # Store secret
        store_secret "${key}" "${secret}"
        break
    done
}

# Main setup - Required secrets
echo -e "${BLUE}Setting up required secrets...${NC}"

prompt_secret "DATABASE_PASSWORD" "PostgreSQL password for nextgen_plaid user" 32 "false"
prompt_secret "PLAID_CLIENT_ID" "Plaid API Client ID" 16 "false"
prompt_secret "PLAID_SECRET" "Plaid API Secret (development or production)" 16 "false"
prompt_secret "CLAUDE_API_KEY" "Anthropic Claude API Key" 20 "false"
prompt_secret "RAILS_MASTER_KEY" "Rails master key for credentials encryption" 16 "false"

echo ""
echo -e "${BLUE}Setting up optional secrets...${NC}"

prompt_secret "REDIS_PASSWORD" "Redis password (if authentication enabled)" 8 "true"
prompt_secret "SENTRY_DSN" "Sentry error tracking DSN" 8 "true"

# Test database connectivity if password was set
echo ""
echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}→ Testing database connectivity...${NC}"

if test_secret "DATABASE_PASSWORD"; then
    DB_PASS=$(security find-generic-password -a "${SERVICE_PREFIX}" -s "${SERVICE_PREFIX}-DATABASE_PASSWORD" -w 2>/dev/null)
    
    PSQL="/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql"
    if [[ -x "${PSQL}" ]]; then
        if PGPASSWORD="${DB_PASS}" "${PSQL}" -U nextgen_plaid -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Database connection successful${NC}"
        else
            echo -e "${RED}✗ Database connection failed${NC}"
            echo -e "${YELLOW}  Please verify the password and PostgreSQL configuration${NC}"
        fi
    else
        echo -e "${YELLOW}⊙ PostgreSQL not found at expected location, skipping test${NC}"
    fi
else
    echo -e "${YELLOW}⊙ Skipped (no database password stored)${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Secrets stored in macOS Keychain:${NC}"

# List of all possible secrets
ALL_SECRETS="DATABASE_PASSWORD PLAID_CLIENT_ID PLAID_SECRET CLAUDE_API_KEY RAILS_MASTER_KEY REDIS_PASSWORD SENTRY_DSN"

for key in ${ALL_SECRETS}; do
    if test_secret "${key}"; then
        echo -e "  ${GREEN}✓${NC} ${key}"
    fi
done

echo ""
echo -e "${BLUE}To retrieve a secret:${NC}"
echo -e "  security find-generic-password -a '${SERVICE_PREFIX}' -s '${SERVICE_PREFIX}-<KEY>' -w"
echo ""
echo -e "${BLUE}Example:${NC}"
echo -e "  security find-generic-password -a '${SERVICE_PREFIX}' -s '${SERVICE_PREFIX}-DATABASE_PASSWORD' -w"
echo ""
echo -e "${BLUE}To use in scripts:${NC}"
echo -e "  export NEXTGEN_PLAID_DATABASE_PASSWORD=\$(security find-generic-password -a '${SERVICE_PREFIX}' -s '${SERVICE_PREFIX}-DATABASE_PASSWORD' -w)"
echo ""
