#!/usr/bin/env bash
# ============================================================================
# SmartProxy PRD-5.1 (ModelFilter) — Complete Step by Step
# ============================================================================
# Run each step one at a time. Wait for each to complete before the next.
# ============================================================================

SP="/Users/ericsmith66/development/legion/projects/SmartProxy"
PRD="$SP/knowledge_base/epics/epic-5-unified-model-discovery/prd-5-1-model-filter.md"

echo "=== STEP 0: Set Architect to grok-4-latest ==="
rails runner scripts/set_agent_model.rb "$SP" "Architect" grok-4-latest

echo ""
echo "=== STEP 0b: Verify team lineup ==="
rails runner scripts/set_agent_model.rb --show "$SP"

echo ""
echo "=== STEP 1: Decompose PRD-5.1 into tasks ==="
bin/legion decompose \
  --team ROR \
  --prd "$PRD" \
  --project "$SP" \
  --verbose

echo ""
echo "=== STEP 2: Get workflow run ID ==="
WORKFLOW_ID=$(rails runner "
run = WorkflowRun.joins(:project)
  .where(projects: {path: '$SP'})
  .order(id: :desc).first
puts run.id
")
echo "Workflow Run ID: $WORKFLOW_ID"

rails runner "
run = WorkflowRun.find($WORKFLOW_ID)
puts 'Status: ' + run.status.to_s
puts 'Tasks: ' + run.tasks.count.to_s
run.tasks.order(:position).each do |t|
  puts '  Task ' + t.position.to_s + ': [' + t.task_type.to_s + '] ' + t.prompt.to_s[0..70]
end
"

echo ""
echo "=== STEP 3: Dry run (preview execution waves) ==="
bin/legion execute-plan --workflow-run "$WORKFLOW_ID" --dry-run

echo ""
echo "============================================================================"
echo "Review the dry run above. When ready, run Step 4:"
echo ""
echo "  bin/legion execute-plan --workflow-run $WORKFLOW_ID --verbose"
echo ""
echo "After execution completes, verify with Step 5:"
echo ""
echo "  ls $SP/lib/model_filter.rb"
echo "  ls $SP/spec/lib/model_filter_spec.rb"
echo "  cd $SP && bundle exec rspec spec/lib/model_filter_spec.rb"
echo "============================================================================"
