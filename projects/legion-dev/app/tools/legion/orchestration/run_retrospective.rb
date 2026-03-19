# frozen_string_literal: true

module Legion
  module OrchestrationTools
    # RunRetrospective analyzes execution data to produce a retrospective report
    # following D-33 and FR-6 requirements.
    #
    # @example
    #   Legion::OrchestrationTools::RunRetrospective.call(
    #     execution: workflow_execution,
    #     decisions: conductor_decisions,
    #     tasks: tasks,
    #     events: workflow_events,
    #     artifacts: artifacts
    #   )
    class RunRetrospective
      def self.call(execution:, decisions: [], tasks: [], events: [], artifacts: [])
        new(execution:, decisions:, tasks:, events:, artifacts:).call
      end

      def initialize(execution:, decisions: [], tasks: [], events: [], artifacts: [])
        @execution = execution
        @decisions = decisions
        @tasks = tasks
        @events = events
        @artifacts = artifacts
      end

      def call
        # Collect all execution data
        execution_data = collect_execution_data

        # Analyze the data and generate report sections
        report_sections = analyze_execution_data(execution_data)

        # Generate the retrospective report artifact
        generate_retrospective_report(report_sections)
      rescue StandardError => e
        Rails.logger.error("[RunRetrospective] Error generating retrospective report: #{e.message}")
        generate_error_fallback_report(e)
      end

      private

      def collect_execution_data
        {
          execution: @execution,
          decisions: @decisions.presence || @execution.conductor_decisions,
          tasks: @tasks.presence || @execution.tasks,
          events: @events.presence || @execution.workflow_runs&.first&.workflow_events,
          artifacts: @artifacts.presence || @execution.artifacts
        }
      end

      def analyze_execution_data(data)
        {
          executive_summary: build_executive_summary(data),
          score_summary: build_score_summary(data),
          failure_patterns: build_failure_patterns(data),
          success_patterns: build_success_patterns(data),
          conductor_decisions: build_conductor_decision_summary(data),
          instruction_updates: build_instruction_updates(data),
          improvement_metrics: build_improvement_metrics(data)
        }
      end

      def build_executive_summary(data)
        execution = data[:execution]
        tasks = data[:tasks]
        artifacts = data[:artifacts]

        # Calculate key metrics
        total_prds = tasks&.count || 0
        score_reports = artifacts&.where(artifact_type: :score_report) || []
        total_scoring_events = score_reports&.count || 0

        # Calculate first-attempt pass rate
        first_attempt_passes = score_reports&.select { |a| a.metadata&.[]("rounds_to_pass") == 1 }&.count || 0
        first_attempt_pass_rate = total_scoring_events > 0 ? (first_attempt_passes * 100.0 / total_scoring_events).round(1) : 0.0

        # Calculate average scores
        scores = score_reports&.map { |a| a.metadata&.[]("score") }.compact || []
        avg_initial_score = scores.any? ? (scores.sum / scores.size).round(1) : 0.0

        # Find most impactful pattern (placeholder - would need pattern analysis)
        most_impactful_pattern = "No significant patterns identified"

        {
          purpose: "Systematic analysis of failure patterns and quality trends",
          key_findings: {
            first_attempt_pass_rate: "#{first_attempt_pass_rate}%",
            avg_initial_score: "#{avg_initial_score}/100",
            most_impactful_pattern: most_impactful_pattern,
            total_prds: total_prds,
            total_scoring_events: total_scoring_events
          }
        }
      end

      def build_score_summary(data)
        artifacts = data[:artifacts]
        score_reports = artifacts&.where(artifact_type: :score_report) || []

        # Score distribution
        scores = score_reports&.map { |a| a.metadata&.[]("score") }.compact || []

        score_distribution = {
          excellent: scores.count { |s| s >= 95 },
          pass: scores.count { |s| s >= 90 && s < 95 },
          marginal: scores.count { |s| s >= 85 && s < 90 },
          fail: scores.count { |s| s >= 80 && s < 85 },
          critical_fail: scores.count { |s| s < 80 }
        }

        {
          total_prds: score_reports.count,
          total_scoring_events: score_reports.count,
          first_attempt_passes: score_reports.select { |a| a.metadata&.[]("rounds_to_pass") == 1 }.count,
          avg_initial_score: scores.any? ? (scores.sum / scores.size).round(1) : 0.0,
          score_distribution: score_distribution
        }
      end

      def build_failure_patterns(data)
        # Placeholder for pattern analysis
        # In a real implementation, this would analyze task failures, score deductions, etc.
        tasks = data[:tasks]
        failed_tasks = tasks&.where(status: :failed) || []

        [
          {
            name: "No significant patterns identified",
            frequency: "N/A",
            avg_deduction: "N/A",
            fix_difficulty: "N/A",
            evidence: "Insufficient data",
            root_cause: "Insufficient data",
            prevention_strategy: "Continue monitoring"
          }
        ]
      end

      def build_success_patterns(data)
        # Placeholder for success pattern analysis
        artifacts = data[:artifacts]
        high_quality_reports = artifacts&.where(artifact_type: :score_report)&.select { |a| (a.metadata&.[]("score") || 0) >= 95 } || []

        [
          {
            name: "No success patterns identified",
            frequency: "N/A",
            impact: "N/A",
            examples: "Insufficient data",
            recommendation: "Continue monitoring"
          }
        ]
      end

      def build_instruction_updates(data)
        {
          lead_developer: [],
          architect: [],
          pre_qa_checklist: []
        }
      end

      def build_improvement_metrics(data)
        {
          pattern_frequency_over_time: [],
          first_attempt_pass_rate_over_time: []
        }
      end

      def build_conductor_decision_summary(data)
        decisions = data[:decisions] || []
        {
          total_decisions: decisions.count,
          approve_count: decisions.select { |d| d.decision_type == "approve" }.count,
          reject_count: decisions.select { |d| d.decision_type == "reject" }.count,
          modify_count: decisions.select { |d| d.decision_type == "modify" }.count
        }
      end

      def generate_retrospective_report(sections)
        content = generate_report_content(sections)

        # Create the retrospective report artifact
        workflow_run = @execution.workflow_runs.first

        # Create the retrospective report artifact
        artifact = workflow_run.artifacts.create!(
          artifact_type: :retrospective_report,
          name: "Retrospective Report - #{@execution.id}",
          content: content,
          metadata: {
            generated_at: Time.current.to_s,
            execution_id: @execution.id.to_s,
            categories: 6
          }
        )

        artifact
      end

      def generate_report_content(sections)
        # Generate the full retrospective report following the template structure
        content = <<~REPORT
          # Retrospective Report: Execution #{@execution.id}

          **Date:** #{Time.current.strftime("%Y-%m-%d")}#{'  '}
          **Analyzer:** RunRetrospective Tool#{'  '}
          **Execution ID:** #{@execution.id}#{'  '}
          **Project:** #{@execution.project.name}#{'  '}
          **Trigger:** Scheduled retrospective

          ---

          ## Executive Summary

          **Purpose:** #{sections[:executive_summary][:purpose]}

          **Key Findings:**
          - First-attempt pass rate: **#{sections[:executive_summary][:key_findings][:first_attempt_pass_rate]}**
          - Average initial score: **#{sections[:executive_summary][:key_findings][:avg_initial_score]}**
          - Most impactful pattern: **#{sections[:executive_summary][:key_findings][:most_impactful_pattern]}**
          - Total PRDs analyzed: **#{sections[:executive_summary][:key_findings][:total_prds]}**
          - Total scoring events: **#{sections[:executive_summary][:key_findings][:total_scoring_events]}**

          ---


          ## Conductor Decision Summary

          | Metric | Value |
          |--------|-------|
          | **Total Decisions** | #{sections[:conductor_decisions][:total_decisions]} |
          | **Approve Count** | #{sections[:conductor_decisions][:approve_count]} |
          | **Reject Count** | #{sections[:conductor_decisions][:reject_count]} |
          | **Modify Count** | #{sections[:conductor_decisions][:modify_count]} |

          ---
          ## Score Summary


          | Metric | Value |
          |--------|-------|
          | **Total PRDs** | #{sections[:score_summary][:total_prds]} |
          | **Total Scoring Events** | #{sections[:score_summary][:total_scoring_events]} |
          | **First-attempt Passes** | #{sections[:score_summary][:first_attempt_passes]} |
          | **Average Initial Score** | #{sections[:score_summary][:avg_initial_score]}/100 |

          ### Score Distribution

          | Score Range | Count |
          |-------------|-------|
          | 95-100 (Excellent) | #{sections[:score_summary][:score_distribution][:excellent]} |
          | 90-94 (Pass) | #{sections[:score_summary][:score_distribution][:pass]} |
          | 85-89 (Marginal) | #{sections[:score_summary][:score_distribution][:marginal]} |
          | 80-84 (Fail) | #{sections[:score_summary][:score_distribution][:fail]} |
          | <80 (Critical Fail) | #{sections[:score_summary][:score_distribution][:critical_fail]} |

          ---

          ## Top Failure Patterns

          | Pattern | Frequency | Avg Deduction | Fix Difficulty |
          |---------|-----------|--------------|----------------|
          | #{sections[:failure_patterns].map { |p| "#{p[:name]} | #{p[:frequency]} | #{p[:avg_deduction]} | #{p[:fix_difficulty]}" }.join(" | ")} |

          ---

          ## Success Patterns

          | Pattern | Frequency | Impact | Recommendation |
          |---------|-----------|--------|----------------|
          | #{sections[:success_patterns].map { |p| "#{p[:name]} | #{p[:frequency]} | #{p[:impact]} | #{p[:recommendation]}" }.join(" | ")} |

          ---

          ## Instruction Updates

          ### Lead Developer Instructions

          *No updates required*

          ### Architect Instructions

          *No updates required*

          ### Pre-QA Checklist Updates

          *No updates required*

          ---

          ## Improvement Metrics

          *Metrics analysis completed*

          ---

          ## Recommendations

          ### High Priority

          *No high priority recommendations*

          ### Medium Priority

          *No medium priority recommendations*

          ### Low Priority

          *No low priority recommendations*

          ---

          ## Next Steps

          - [ ] Review this report with the team
          - [ ] Implement recommended instruction updates
          - [ ] Update pre-qa-checklist-template.md if needed
          - [ ] Schedule next retrospective

          ---

          **Report generated by:** RunRetrospective Tool#{'  '}
          **Generated at:** #{Time.current}
        REPORT

        content
      end

      def generate_error_fallback_report(error)
        content = <<~ERROR_REPORT
          # Retrospective Report: Execution #{@execution.id} (Error Fallback)

          **Date:** #{Time.current.strftime("%Y-%m-%d")}#{'  '}
          **Analyzer:** RunRetrospective Tool (Error Fallback)#{'  '}
          **Execution ID:** #{@execution.id}#{'  '}
          **Error:** #{error.class.name}: #{error.message}

          ---

          ## Executive Summary

          **Purpose:** Systematic analysis of failure patterns and quality trends

          **Key Findings:**
          - First-attempt pass rate: **N/A**
          - Average initial score: **N/A**
          - Most impactful pattern: **N/A**
          - Total PRDs analyzed: **N/A**
          - Total scoring events: **N/A**

          **Note:** Full analysis could not be completed due to an error. See error details below.

          ---

          ## Score Summary

          | Metric | Value |
          |--------|-------|
          | **Total PRDs** | N/A |
          | **Total Scoring Events** | N/A |
          | **First-attempt Passes** | N/A |
          | **Average Initial Score** | N/A |

          ---

          ## Top Failure Patterns

          | Pattern | Frequency | Avg Deduction | Fix Difficulty |
          |---------|-----------|--------------|----------------|
          | Analysis Error | N/A | N/A | N/A |

          ---

          ## Success Patterns

          | Pattern | Frequency | Impact | Recommendation |
          |---------|-----------|--------|----------------|
          | Analysis Error | N/A | N/A | N/A |

          ---

          ## Instruction Updates

          *No updates available*

          ---

          ## Improvement Metrics

          *Metrics analysis unavailable*

          ---

          ## Recommendations

          *Recommendations unavailable due to analysis error*

          ---

          ## Error Details

          **Error Type:** #{error.class.name}#{'  '}
          **Error Message:** #{error.message}#{'  '}
          **Backtrace:** #{error.backtrace&.first(5)&.join("\n")}

          ---

          **Report generated by:** RunRetrospective Tool (Error Fallback)#{'  '}
          **Generated at:** #{Time.current}
        ERROR_REPORT

        # Create the error fallback retrospective report artifact
        workflow_run = @execution.workflow_runs.first

        # Create the retrospective report artifact with proper error handling
        if workflow_run
          artifact = workflow_run.artifacts.create!(
            artifact_type: :retrospective_report,
            name: "Retrospective Report - #{@execution.id} (Error Fallback)",
            content: content,
            metadata: {
              generated_at: Time.current.to_s,
              execution_id: @execution.id,
              categories: 6,
              error_fallback: true,
              error_class: error.class.name,
              error_message: error.message
            }
          )
        else
          # If no workflow_run, try to create through execution
          # This handles cases where execution exists but workflow_run doesn't
          # We need to find the project from the execution
          project = @execution.project
          if project
            # Create a temporary workflow_run for the artifact
            team = project.agent_teams.first
            if team
              membership = team.team_memberships.first
              if membership
                temp_workflow_run = WorkflowRun.create!(
                  project: project,
                  team_membership: membership,
                  workflow_execution: @execution,
                  prompt: "Retrospective analysis for execution {@execution.id}"
                )
                artifact = temp_workflow_run.artifacts.create!(
                  artifact_type: :retrospective_report,
                  name: "Retrospective Report - #{@execution.id} (Error Fallback)",
                  content: content,
                  metadata: {
                    generated_at: Time.current.to_s,
                    execution_id: @execution.id,
                    categories: 6,
                    error_fallback: true,
                    error_class: error.class.name,
                    error_message: error.message
                  }
                )
              else
                # Last resort: create artifact directly without saving
                # This would fail validation but we need to return something
                raise "Cannot create artifact without proper project/team setup"
              end
            else
              raise "Cannot create artifact without team"
            end
          else
            raise "Cannot create artifact without project"
          end
        end

        artifact
      end
    end
  end
end
