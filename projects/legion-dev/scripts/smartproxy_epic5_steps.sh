#!/usr/bin/env bash
# ============================================================================
# SmartProxy Epic 5 — Step-by-Step Orchestration via Legion
# ============================================================================
#
# Epic: Unified Live Model Discovery + OpenRouter Integration
# Project: /Users/ericsmith66/development/legion/projects/SmartProxy
# PRDs: 5.1 -> 5.3 -> 5.2 -> 5.4 -> 5.5 (recommended order)
#
# We start with PRD-5.1 (ModelFilter) since everything else depends on it.
# ============================================================================

SP="/Users/ericsmith66/development/legion/projects/SmartProxy"

# ============================================================================
# STEP 1: Decompose PRD-5.1 (ModelFilter)
# ============================================================================
echo "=== STEP 1: Decompose PRD-5.1 ==="
bin/legion decompose \
  --team ROR \
  --prd "$SP/knowledge_base/epics/epic-5-unified-model-discovery/prd-5-1-model-filter.md" \
  --project "$SP" \
  --verbose

# ============================================================================
# STEP 2: Check the workflow run ID
# ============================================================================
echo ""
echo "=== STEP 2: Get workflow run ID ==="
rails runner "
run = WorkflowRun.joins(:project).where(projects: {path: '$SP'}).where(status: :completed).order(id: :desc).first
puts 'Workflow Run ID: ' + run.id.to_s
puts 'Tasks: ' + run.tasks.count.to_s
run.tasks.order(:position).each do |t|
  puts '  Task ' + t.position.to_s + ': [' + t.task_type.to_s + '] ' + t.prompt.to_s[0..70]
end
"

# ============================================================================
# STEP 3: Dry run (preview execution waves)
# Replace WORKFLOW_ID with the ID from Step 2
# ============================================================================
echo ""
echo "=== STEP 3: Dry run ==="
echo "Run: bin/legion execute-plan --workflow-run WORKFLOW_ID --dry-run"
echo "(Replace WORKFLOW_ID with the number from Step 2)"

# ============================================================================
# STEP 4: Execute the plan for real
# Replace WORKFLOW_ID with the ID from Step 2
# ============================================================================
echo ""
echo "=== STEP 4: Execute ==="
echo "Run: bin/legion execute-plan --workflow-run WORKFLOW_ID --verbose"
echo "(Replace WORKFLOW_ID with the number from Step 2)"

# ============================================================================
# STEP 5: Verify results
# ============================================================================
echo ""
echo "=== STEP 5: Verify ==="
echo "Run: ls $SP/lib/model_filter.rb"
echo "Run: ls $SP/spec/lib/model_filter_spec.rb"
echo "Run: cd $SP && bundle exec rspec spec/lib/model_filter_spec.rb"
