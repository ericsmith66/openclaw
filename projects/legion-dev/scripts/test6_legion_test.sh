#!/usr/bin/env bash
# Test 6: Decompose + Execute targeting projects/legion-test
# This keeps the main Legion codebase clean

# Step 1: Re-decompose targeting legion-test project
bin/legion decompose \
  --team ROR \
  --prd /tmp/test-prd.md \
  --project /Users/ericsmith66/development/legion/projects/legion-test \
  --verbose

# Step 2: Get the new workflow run ID
echo ""
echo "=== Get the workflow run ID from above, then run: ==="
echo "bin/legion execute-plan --workflow-run NEW_ID --verbose"
echo ""
echo "Or do a dry run first:"
echo "bin/legion execute-plan --workflow-run NEW_ID --dry-run"
