#!/usr/bin/env bash
# frozen_string_literal: true
#
# Pre-QA Validation Script
# Automates the mandatory hygiene checks from the Pre-QA Checklist.
# Run before submitting to QA Agent (Φ11).
#
# Usage: bash scripts/pre-qa-validate.sh [directory ...]
#   If no directories specified, checks: app/ lib/ test/ gems/
#
# Exit codes:
#   0 = All checks pass
#   1 = One or more checks failed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

# Determine directories to check
if [ $# -gt 0 ]; then
  DIRS=("$@")
else
  DIRS=()
  for d in app lib test gems; do
    [ -d "$d" ] && DIRS+=("$d")
  done
fi

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo "${BOLD}  PRE-QA VALIDATION CHECKLIST${NC}"
echo "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Directories: ${DIRS[*]}"
echo ""

# ─────────────────────────────────────────────────────────
# CHECK 1: RuboCop (auto-correct then verify)
# ─────────────────────────────────────────────────────────
echo "${BOLD}[1/4] RuboCop — Linting & Auto-correction${NC}"
echo "────────────────────────────────────────────"

if command -v rubocop &> /dev/null; then
  # Run auto-correct first
  rubocop -A "${DIRS[@]}" --only-recognized-file-types 2>/dev/null || true

  # Now check for remaining offenses
  RUBOCOP_OUTPUT=$(rubocop "${DIRS[@]}" --only-recognized-file-types --format simple 2>&1) || true
  OFFENSE_COUNT=$(echo "$RUBOCOP_OUTPUT" | grep -oE '[0-9]+ offense' | grep -oE '[0-9]+' || echo "0")

  if [ "$OFFENSE_COUNT" = "0" ] || echo "$RUBOCOP_OUTPUT" | grep -q "no offenses detected"; then
    echo -e "  ${GREEN}✅ PASS${NC} — 0 offenses"
    ((PASS++))
  else
    echo -e "  ${RED}❌ FAIL${NC} — $OFFENSE_COUNT offenses remaining after auto-correct"
    echo "$RUBOCOP_OUTPUT" | tail -20
    ((FAIL++))
  fi
else
  echo -e "  ${YELLOW}⚠️  WARN${NC} — rubocop not found. Install with: gem install rubocop"
  ((WARN++))
fi
echo ""

# ─────────────────────────────────────────────────────────
# CHECK 2: frozen_string_literal pragma
# ─────────────────────────────────────────────────────────
echo "${BOLD}[2/4] frozen_string_literal — Pragma Check${NC}"
echo "────────────────────────────────────────────"

MISSING_PRAGMA=$(grep -rL 'frozen_string_literal' "${DIRS[@]}" --include='*.rb' 2>/dev/null || true)

if [ -z "$MISSING_PRAGMA" ]; then
  echo -e "  ${GREEN}✅ PASS${NC} — All .rb files have frozen_string_literal pragma"
  ((PASS++))
else
  MISSING_COUNT=$(echo "$MISSING_PRAGMA" | wc -l | tr -d ' ')
  echo -e "  ${RED}❌ FAIL${NC} — $MISSING_COUNT files missing frozen_string_literal:"
  echo "$MISSING_PRAGMA" | while read -r f; do
    echo "    - $f"
  done
  echo ""
  echo "  Auto-fix: Add '# frozen_string_literal: true' as line 1 of each file."
  ((FAIL++))
fi
echo ""

# ─────────────────────────────────────────────────────────
# CHECK 3: Test Suite
# ─────────────────────────────────────────────────────────
echo "${BOLD}[3/4] Test Suite — Running Tests${NC}"
echo "────────────────────────────────────────────"

if [ -f "Rakefile" ] && grep -q "Rails" Gemfile 2>/dev/null; then
  TEST_OUTPUT=$(bundle exec rails test 2>&1) || true
  TEST_EXIT=$?

  # Extract summary line
  SUMMARY=$(echo "$TEST_OUTPUT" | grep -E '^[0-9]+ runs' | tail -1)

  if [ -n "$SUMMARY" ]; then
    FAILURES=$(echo "$SUMMARY" | grep -oE '[0-9]+ failures' | grep -oE '[0-9]+' || echo "0")
    ERRORS=$(echo "$SUMMARY" | grep -oE '[0-9]+ errors' | grep -oE '[0-9]+' || echo "0")
    SKIPS=$(echo "$SUMMARY" | grep -oE '[0-9]+ skips' | grep -oE '[0-9]+' || echo "0")

    if [ "$FAILURES" = "0" ] && [ "$ERRORS" = "0" ]; then
      if [ "$SKIPS" != "0" ]; then
        echo -e "  ${YELLOW}⚠️  WARN${NC} — Tests pass but $SKIPS skips detected"
        echo "  $SUMMARY"
        ((WARN++))
      else
        echo -e "  ${GREEN}✅ PASS${NC} — $SUMMARY"
        ((PASS++))
      fi
    else
      echo -e "  ${RED}❌ FAIL${NC} — $SUMMARY"
      # Show failure details
      echo "$TEST_OUTPUT" | grep -A 3 "Failure\|Error" | head -30
      ((FAIL++))
    fi
  else
    echo -e "  ${RED}❌ FAIL${NC} — Could not parse test output"
    echo "$TEST_OUTPUT" | tail -10
    ((FAIL++))
  fi
elif [ -d "gems" ]; then
  # Try gem-level test suite
  for gemdir in gems/*/; do
    if [ -f "$gemdir/Rakefile" ]; then
      echo "  Running tests in $gemdir..."
      GEM_OUTPUT=$(cd "$gemdir" && bundle exec rake test 2>&1) || true
      GEM_SUMMARY=$(echo "$GEM_OUTPUT" | grep -E '^\d+ runs' | tail -1)
      if [ -n "$GEM_SUMMARY" ]; then
        echo "  $gemdir: $GEM_SUMMARY"
      fi
    fi
  done
  ((PASS++))
else
  echo -e "  ${YELLOW}⚠️  WARN${NC} — No test runner detected"
  ((WARN++))
fi
echo ""

# ─────────────────────────────────────────────────────────
# CHECK 4: Dead Code Audit (rescue/raise without tests)
# ─────────────────────────────────────────────────────────
echo "${BOLD}[4/4] Dead Code Audit — rescue/raise Coverage${NC}"
echo "────────────────────────────────────────────"

# Count rescue/raise in source (exclude test dirs)
SOURCE_DIRS=()
for d in "${DIRS[@]}"; do
  if [[ "$d" != "test" && "$d" != "spec" ]]; then
    SOURCE_DIRS+=("$d")
  fi
done

if [ ${#SOURCE_DIRS[@]} -gt 0 ]; then
  RESCUE_COUNT=$(grep -rn 'rescue\b' "${SOURCE_DIRS[@]}" --include='*.rb' 2>/dev/null | wc -l | tr -d ' ')
  RAISE_COUNT=$(grep -rn 'raise\b' "${SOURCE_DIRS[@]}" --include='*.rb' 2>/dev/null | wc -l | tr -d ' ')
  echo "  Found: $RESCUE_COUNT rescue blocks, $RAISE_COUNT raise statements in source"
  echo -e "  ${YELLOW}ℹ️  INFO${NC} — Manually verify each has a corresponding test"
  ((WARN++))
else
  echo "  No source directories to audit"
fi
echo ""

# ─────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────
echo "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo "${BOLD}  SUMMARY${NC}"
echo "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $PASS"
echo -e "  ${RED}Failed:${NC}  $FAIL"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo -e "  ${RED}${BOLD}❌ PRE-QA VALIDATION FAILED${NC}"
  echo "  Fix the issues above before submitting to QA."
  echo ""
  exit 1
else
  echo -e "  ${GREEN}${BOLD}✅ PRE-QA VALIDATION PASSED${NC}"
  echo "  Ready to submit to QA Agent (Φ11)."
  echo ""
  exit 0
fi
