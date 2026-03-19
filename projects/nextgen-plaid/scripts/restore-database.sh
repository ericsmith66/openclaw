#!/usr/bin/env bash
#
# Database Restore Script for nextgen-plaid
# Purpose: Restore databases from timestamped backup files
# Usage: ./scripts/restore-database.sh [TIMESTAMP]
#        ./scripts/restore-database.sh --list
#
# Examples:
#   ./scripts/restore-database.sh 20260222_143015
#   ./scripts/restore-database.sh --list
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${HOME}/backups/nextgen-plaid"
PG_RESTORE="/opt/homebrew/opt/postgresql@16/bin/pg_restore"
PSQL="/opt/homebrew/opt/postgresql@16/bin/psql"

# Databases to restore
DATABASES=(
    "nextgen_plaid_production"
    "nextgen_plaid_production_queue"
    "nextgen_plaid_production_cable"
    "nextgen_plaid_production_cache"
)

# Function to list available backups
list_backups() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Available Database Backups${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        echo -e "${RED}No backup directory found at ${BACKUP_DIR}${NC}"
        exit 1
    fi
    
    # Get unique timestamps
    TIMESTAMPS=$(find "${BACKUP_DIR}" -name "*.dump" -type f | \
        sed -E 's/.*\/([0-9]{8}_[0-9]{6})_.*/\1/' | \
        sort -r | uniq)
    
    if [[ -z "${TIMESTAMPS}" ]]; then
        echo -e "${YELLOW}No backups found${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}Timestamp            Date & Time           Files  Total Size${NC}"
    echo -e "${BLUE}──────────────────   ───────────────────   ─────  ──────────${NC}"
    
    while IFS= read -r timestamp; do
        # Parse timestamp
        DATE_PART="${timestamp:0:8}"
        TIME_PART="${timestamp:9:6}"
        
        # Format for display
        DISPLAY_DATE="${DATE_PART:0:4}-${DATE_PART:4:2}-${DATE_PART:6:2}"
        DISPLAY_TIME="${TIME_PART:0:2}:${TIME_PART:2:2}:${TIME_PART:4:2}"
        
        # Count files and calculate total size
        FILES=$(find "${BACKUP_DIR}" -name "${timestamp}_*.dump" -type f | wc -l | tr -d ' ')
        TOTAL_SIZE=$(find "${BACKUP_DIR}" -name "${timestamp}_*.dump" -type f -exec du -ch {} + | \
            grep total | cut -f1)
        
        printf "%-20s %-21s %-6s %s\n" \
            "${timestamp}" \
            "${DISPLAY_DATE} ${DISPLAY_TIME}" \
            "${FILES}" \
            "${TOTAL_SIZE}"
    done <<< "${TIMESTAMPS}"
    
    echo ""
    echo -e "${BLUE}To restore a backup, run:${NC}"
    echo -e "  ./scripts/restore-database.sh ${BLUE}<TIMESTAMP>${NC}"
    echo ""
    exit 0
}

# Function to terminate database connections
terminate_connections() {
    local db_name=$1
    echo -e "${YELLOW}  → Terminating active connections to ${db_name}...${NC}"
    
    "${PSQL}" -d postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${db_name}' AND pid <> pg_backend_pid();" \
        > /dev/null 2>&1 || true
    
    echo -e "${GREEN}  ✓ Connections terminated${NC}"
}

# Function to verify backup file
verify_backup_file() {
    local backup_file=$1
    
    if [[ ! -f "${backup_file}" ]]; then
        echo -e "${RED}✗ Backup file not found: ${backup_file}${NC}"
        return 1
    fi
    
    if [[ ! -s "${backup_file}" ]]; then
        echo -e "${RED}✗ Backup file is empty: ${backup_file}${NC}"
        return 1
    fi
    
    # Check if file is a valid PostgreSQL dump
    if ! file "${backup_file}" | grep -q "PostgreSQL custom database dump"; then
        echo -e "${RED}✗ File is not a valid PostgreSQL dump: ${backup_file}${NC}"
        return 1
    fi
    
    return 0
}

# Function to restore a single database
restore_database() {
    local backup_file=$1
    local db_name=$2
    
    echo -e "${YELLOW}→ Restoring ${db_name}...${NC}"
    
    # Verify backup file
    if ! verify_backup_file "${backup_file}"; then
        echo -e "${RED}✗ Restore failed: Invalid backup file${NC}"
        return 1
    fi
    
    FILE_SIZE=$(du -h "${backup_file}" | cut -f1)
    echo -e "${BLUE}  → Backup file: $(basename "${backup_file}") (${FILE_SIZE})${NC}"
    
    # Terminate connections
    terminate_connections "${db_name}"
    
    # Restore database
    echo -e "${YELLOW}  → Restoring data...${NC}"
    if "${PG_RESTORE}" --no-owner --no-acl --clean --if-exists \
        --dbname="${db_name}" "${backup_file}" 2>&1 | grep -q "processing"; then
        echo -e "${GREEN}✓ Restore successful: ${db_name}${NC}"
        return 0
    else
        echo -e "${RED}✗ Restore failed: ${db_name}${NC}"
        return 1
    fi
}

# Function to verify restoration
verify_restoration() {
    local db_name=$1
    
    echo -e "${YELLOW}  → Verifying ${db_name}...${NC}"
    
    # Count tables
    TABLE_COUNT=$("${PSQL}" -d "${db_name}" -t -c \
        "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';" | tr -d ' ')
    
    echo -e "${GREEN}  ✓ Verification passed: ${TABLE_COUNT} tables found${NC}"
}

# Main script
main() {
    # Check for --list flag
    if [[ "${1:-}" == "--list" ]]; then
        list_backups
    fi
    
    # Check if timestamp provided
    if [[ $# -eq 0 ]]; then
        echo -e "${RED}Error: No timestamp provided${NC}"
        echo ""
        echo -e "${BLUE}Usage:${NC}"
        echo -e "  $0 ${BLUE}<TIMESTAMP>${NC}    - Restore from specific backup"
        echo -e "  $0 --list         - List available backups"
        echo ""
        echo -e "${BLUE}Example:${NC}"
        echo -e "  $0 20260222_143015"
        echo ""
        exit 1
    fi
    
    TIMESTAMP=$1
    
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Database Restore - nextgen-plaid${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Timestamp: ${TIMESTAMP}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    # Verify backup directory exists
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        echo -e "${RED}✗ Backup directory not found: ${BACKUP_DIR}${NC}"
        exit 1
    fi
    
    # Count available backup files for this timestamp
    AVAILABLE_BACKUPS=$(find "${BACKUP_DIR}" -name "${TIMESTAMP}_*.dump" -type f | wc -l | tr -d ' ')
    
    if [[ ${AVAILABLE_BACKUPS} -eq 0 ]]; then
        echo -e "${RED}✗ No backup files found for timestamp: ${TIMESTAMP}${NC}"
        echo ""
        echo -e "${YELLOW}Run './scripts/restore-database.sh --list' to see available backups${NC}"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✓ Found ${AVAILABLE_BACKUPS} backup file(s) for timestamp ${TIMESTAMP}${NC}"
    echo ""
    
    # List files to be restored
    echo -e "${BLUE}Backup files:${NC}"
    find "${BACKUP_DIR}" -name "${TIMESTAMP}_*.dump" -type f | while read -r file; do
        SIZE=$(du -h "${file}" | cut -f1)
        echo -e "  - $(basename "${file}") (${SIZE})"
    done
    echo ""
    
    # Confirmation
    echo -e "${YELLOW}⚠️  WARNING: This will OVERWRITE the current production databases!${NC}"
    echo ""
    read -p "Continue with restore? (type 'yes' to proceed): " -r
    echo ""
    
    if [[ ! $REPLY =~ ^yes$ ]]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        exit 0
    fi
    
    # Track success/failure
    RESTORE_SUCCESS=0
    RESTORE_FAILED=0
    FAILED_DBS=()
    
    # Restore each database
    for DB in "${DATABASES[@]}"; do
        BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_${DB}.dump"
        
        if [[ -f "${BACKUP_FILE}" ]]; then
            if restore_database "${BACKUP_FILE}" "${DB}"; then
                verify_restoration "${DB}"
                ((RESTORE_SUCCESS++))
            else
                ((RESTORE_FAILED++))
                FAILED_DBS+=("${DB}")
            fi
            echo ""
        else
            echo -e "${YELLOW}⚠ Skipping ${DB} (backup file not found)${NC}"
            echo ""
        fi
    done
    
    # Summary
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Restore Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✓${NC} Successful: ${RESTORE_SUCCESS}"
    echo -e "  ${RED}✗${NC} Failed:     ${RESTORE_FAILED}"
    
    if [[ ${RESTORE_FAILED} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed databases:${NC}"
        for failed_db in "${FAILED_DBS[@]}"; do
            echo -e "  - ${failed_db}"
        done
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    # Exit with appropriate code
    if [[ ${RESTORE_FAILED} -gt 0 ]]; then
        echo -e "${RED}Restore completed with errors (exit code 1)${NC}"
        exit 1
    else
        echo -e "${GREEN}All databases restored successfully (exit code 0)${NC}"
        exit 0
    fi
}

# Run main function
main "$@"
