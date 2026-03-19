# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_18_092636) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "project_id"
    t.jsonb "team_rules", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_agent_teams_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_agent_teams_on_project_id"
  end

  create_table "artifacts", force: :cascade do |t|
    t.string "artifact_type", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.bigint "parent_artifact_id"
    t.bigint "project_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0.0", null: false
    t.integer "version_number", default: 1, null: false
    t.bigint "workflow_execution_id"
    t.bigint "workflow_run_id", null: false
    t.index ["artifact_type"], name: "index_artifacts_on_artifact_type"
    t.index ["created_by_id"], name: "index_artifacts_on_created_by_id"
    t.index ["parent_artifact_id"], name: "index_artifacts_on_parent_artifact_id"
    t.index ["project_id", "name"], name: "index_artifacts_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_artifacts_on_project_id"
    t.index ["status"], name: "index_artifacts_on_status"
    t.index ["version_number"], name: "index_artifacts_on_version_number"
    t.index ["workflow_execution_id"], name: "index_artifacts_on_workflow_execution_id"
    t.index ["workflow_run_id"], name: "index_artifacts_on_workflow_run_id"
  end

  create_table "conductor_decisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "decision_type", null: false
    t.integer "duration_ms"
    t.decimal "estimated_cost", precision: 10, scale: 4
    t.string "from_phase"
    t.text "input_summary"
    t.jsonb "payload", default: {}
    t.text "reasoning"
    t.string "to_phase"
    t.integer "tokens_used"
    t.jsonb "tool_args"
    t.string "tool_name"
    t.datetime "updated_at", null: false
    t.bigint "workflow_execution_id", null: false
    t.index ["decision_type"], name: "index_conductor_decisions_on_decision_type"
    t.index ["duration_ms"], name: "index_conductor_decisions_on_duration_ms"
    t.index ["estimated_cost"], name: "index_conductor_decisions_on_estimated_cost"
    t.index ["tokens_used"], name: "index_conductor_decisions_on_tokens_used"
    t.index ["workflow_execution_id"], name: "index_conductor_decisions_on_workflow_execution_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "path", null: false
    t.jsonb "project_rules", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["path"], name: "index_projects_on_path", unique: true
  end

  create_table "task_dependencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "depends_on_task_id", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["depends_on_task_id"], name: "index_task_dependencies_on_depends_on_task_id"
    t.index ["task_id", "depends_on_task_id"], name: "index_task_deps_on_task_and_depends_on", unique: true
    t.index ["task_id"], name: "index_task_dependencies_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "concepts_score"
    t.datetime "created_at", null: false
    t.integer "dependencies_score"
    t.text "error_message"
    t.integer "estimated_iterations"
    t.bigint "execution_run_id"
    t.integer "files_score"
    t.text "last_error"
    t.jsonb "metadata", default: {}, null: false
    t.integer "position", default: 0, null: false
    t.bigint "project_id", null: false
    t.text "prompt", null: false
    t.datetime "queued_at"
    t.text "result"
    t.integer "retry_count", default: 0
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "task_type", null: false
    t.bigint "team_membership_id", null: false
    t.integer "total_score"
    t.datetime "updated_at", null: false
    t.bigint "workflow_execution_id"
    t.bigint "workflow_run_id"
    t.index ["execution_run_id"], name: "index_tasks_on_execution_run_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["team_membership_id"], name: "index_tasks_on_team_membership_id"
    t.index ["workflow_execution_id"], name: "index_tasks_on_workflow_execution_id"
    t.index ["workflow_run_id", "position"], name: "index_tasks_on_workflow_run_id_and_position"
    t.index ["workflow_run_id"], name: "index_tasks_on_workflow_run_id"
  end

  create_table "team_memberships", force: :cascade do |t|
    t.bigint "agent_team_id", null: false
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["agent_team_id", "position"], name: "index_team_memberships_on_agent_team_id_and_position"
    t.index ["agent_team_id"], name: "index_team_memberships_on_agent_team_id"
  end

  create_table "workflow_events", force: :cascade do |t|
    t.string "agent_id"
    t.string "channel"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "recorded_at", null: false
    t.string "task_id"
    t.datetime "updated_at", null: false
    t.bigint "workflow_run_id", null: false
    t.index ["recorded_at"], name: "index_workflow_events_on_recorded_at"
    t.index ["workflow_run_id", "event_type"], name: "index_workflow_events_on_workflow_run_id_and_event_type"
    t.index ["workflow_run_id"], name: "index_workflow_events_on_workflow_run_id"
  end

  create_table "workflow_executions", force: :cascade do |t|
    t.integer "attempt", default: 0, null: false
    t.integer "concurrency", default: 3, null: false
    t.datetime "conductor_locked_at"
    t.datetime "created_at", null: false
    t.integer "decomposition_attempt", default: 0, null: false
    t.jsonb "metadata"
    t.string "phase", default: "decomposing", null: false
    t.string "prd_content_hash"
    t.string "prd_path", null: false
    t.text "prd_snapshot"
    t.bigint "project_id", null: false
    t.boolean "sequential", default: false, null: false
    t.string "status", default: "running", null: false
    t.integer "task_retry_limit", default: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["phase"], name: "index_workflow_executions_on_phase"
    t.index ["project_id", "status"], name: "index_workflow_executions_on_project_id_and_status"
    t.index ["project_id"], name: "index_workflow_executions_on_project_id"
    t.index ["status"], name: "index_workflow_executions_on_status"
  end

  create_table "workflow_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "iterations", default: 0
    t.jsonb "metadata", default: {}, null: false
    t.string "phase"
    t.bigint "project_id", null: false
    t.text "prompt", null: false
    t.text "result"
    t.string "status", default: "queued", null: false
    t.bigint "task_id"
    t.bigint "team_membership_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "workflow_execution_id"
    t.index ["created_at"], name: "index_workflow_runs_on_created_at"
    t.index ["phase"], name: "index_workflow_runs_on_phase"
    t.index ["project_id"], name: "index_workflow_runs_on_project_id"
    t.index ["status"], name: "index_workflow_runs_on_status"
    t.index ["task_id"], name: "index_workflow_runs_on_task_id"
    t.index ["team_membership_id"], name: "index_workflow_runs_on_team_membership_id"
    t.index ["workflow_execution_id", "phase"], name: "index_workflow_runs_on_workflow_execution_id_and_phase"
    t.index ["workflow_execution_id"], name: "index_workflow_runs_on_workflow_execution_id"
  end

  add_foreign_key "agent_teams", "projects"
  add_foreign_key "artifacts", "agent_teams", column: "created_by_id"
  add_foreign_key "artifacts", "artifacts", column: "parent_artifact_id"
  add_foreign_key "artifacts", "projects"
  add_foreign_key "artifacts", "workflow_executions"
  add_foreign_key "artifacts", "workflow_runs", on_delete: :cascade
  add_foreign_key "conductor_decisions", "workflow_executions"
  add_foreign_key "task_dependencies", "tasks"
  add_foreign_key "task_dependencies", "tasks", column: "depends_on_task_id"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "team_memberships"
  add_foreign_key "tasks", "workflow_executions"
  add_foreign_key "tasks", "workflow_runs"
  add_foreign_key "tasks", "workflow_runs", column: "execution_run_id"
  add_foreign_key "team_memberships", "agent_teams"
  add_foreign_key "workflow_events", "workflow_runs"
  add_foreign_key "workflow_executions", "projects"
  add_foreign_key "workflow_runs", "projects"
  add_foreign_key "workflow_runs", "tasks"
  add_foreign_key "workflow_runs", "team_memberships"
  add_foreign_key "workflow_runs", "workflow_executions"
end
