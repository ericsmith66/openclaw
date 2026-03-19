# frozen_string_literal: true

module Legion
  class OrchestratorHooksService
    def self.call(hook_manager:, workflow_run:, team_membership:)
      new(hook_manager:, workflow_run:, team_membership:).call
    end

    def initialize(hook_manager:, workflow_run:, team_membership:)
      @hook_manager = hook_manager
      @workflow_run = workflow_run
      @team_membership = team_membership
      @hooks_registered = false
    end

    def call
      return if @hooks_registered

      register_iteration_budget_hook
      register_context_pressure_hook
      register_handoff_capture_hook
      register_cost_budget_hook

      @hooks_registered = true
    end

    private

    def register_iteration_budget_hook
      threshold = OrchestratorHooks.iteration_threshold_for_model(
        @team_membership.config["model"]
      )

      @hook_manager.on(:on_tool_called) do |event_data, context|
        begin
          warn_at_threshold(threshold)
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] Iteration budget hook error: #{e.message}")
          nil
        end
      end
    end

    def register_context_pressure_hook
      @hook_manager.on(:on_token_budget_warning) do |event_data, context|
        begin
          percentage = event_data[:usage_percentage]
          return nil unless percentage

          if percentage >= 80
            @workflow_run.update!(
              status: :decomposing,
              metadata: @workflow_run.metadata.merge({
                "context_warning" => {
                  "percentage" => percentage,
                  "timestamp" => Time.now.to_s,
                  "recommendation" => "Decompose task to reduce context pressure"
                }
              })
            )
            AgentDesk::Hooks::HookResult.new(blocked: true)
          elsif percentage >= 60
            @workflow_run.update!(
              status: :at_risk,
              metadata: @workflow_run.metadata.merge({
                "context_warning" => {
                  "percentage" => percentage,
                  "timestamp" => Time.now.to_s
                }
              })
            )
            AgentDesk::Hooks::HookResult.new(blocked: false)
          else
            AgentDesk::Hooks::HookResult.new(blocked: false)
          end
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] Context pressure hook error: #{e.message}")
          nil
        end
      end
    end

    def register_handoff_capture_hook
      @hook_manager.on(:on_handoff_created) do |event_data, context|
        begin
          handoff_prompt = event_data[:handoff_prompt]
          new_task_id = event_data[:new_task_id]

          # Create new WorkflowRun for continuation
          new_run = @workflow_run.class.create!(
            project: @workflow_run.project,
            team_membership: @workflow_run.team_membership,
            prompt: handoff_prompt,
            status: :queued,
            metadata: { "handed_off_from" => @workflow_run.id.to_s }
          )

          # Update original run
          @workflow_run.update!(
            status: :handed_off,
            metadata: @workflow_run.metadata.merge({
              "handed_off_to" => new_run.id.to_s,
              "handed_off_at" => Time.now.to_s
            })
          )

          AgentDesk::Hooks::HookResult.new(
            blocked: false,
            result: { new_run_id: new_run.id }
          )
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] Handoff hook error: #{e.message}")
          nil
        end
      end
    end

    def register_cost_budget_hook
      @hook_manager.on(:on_cost_budget_exceeded) do |event_data, context|
        begin
          # Return nil (or blocked: false) to allow runner's default :stop behavior
          @workflow_run.update!(
            status: :budget_exceeded,
            metadata: @workflow_run.metadata.merge({
              "cost_exceeded" => {
                "cumulative_cost" => event_data[:cumulative_cost],
                "cost_budget" => event_data[:cost_budget],
                "last_message_cost" => event_data[:last_message_cost],
                "timestamp" => Time.now.to_s
              }
            })
          )

          nil
        rescue StandardError => e
          Rails.logger.error("[OrchestratorHooks] Cost budget hook error: #{e.message}")
          nil
        end
      end
    end

    def warn_at_threshold(threshold)
      # Use a closure variable to track iterations within this service instance
      # to reduce DB writes
      @iteration_count ||= 0
      @iteration_count += 1

      return if @iteration_count < threshold

      Rails.logger.warn(
        "[OrchestratorHooks] Iteration warning: count=#{@iteration_count}, " \
        "threshold=#{threshold}, workflow_run_id=#{@workflow_run.id}"
      )

      if @iteration_count >= threshold * 2
        @workflow_run.update!(
          status: :iteration_limit,
          metadata: @workflow_run.metadata.merge({
            "iteration_count" => @iteration_count,
            "iteration_limit" => {
              "iteration" => @iteration_count,
              "timestamp" => Time.now.to_s
            }
          })
        )
        return AgentDesk::Hooks::HookResult.new(blocked: true)
      end

      # Update metadata with warnings
      current_warnings = @workflow_run.metadata["iteration_warnings"] || []
      current_warnings << {
        "iteration" => @iteration_count,
        "timestamp" => Time.now.to_s
      }

      @workflow_run.update!(
        metadata: @workflow_run.metadata.merge({
          "iteration_count" => @iteration_count,
          "iteration_warnings" => current_warnings
        })
      )

      AgentDesk::Hooks::HookResult.new(blocked: false)
    end
  end
end
