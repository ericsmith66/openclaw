# frozen_string_literal: true

module Legion
  # QualityGate subclass for QA scoring evaluations
  #
  # @see QualityGate
  class QaGate < QualityGate
    def gate_name; "qa"; end
    def prompt_template_phase; :qa_score; end
    def agent_role; "qa"; end
    def default_threshold; 90; end

    private

    def create_artifact_record(score:, message:, dispatch_result:)
      content = if score > 0
                  "## Score\n#{score}/100\n\n## Feedback\n#{message}"
      else
                  "## Score\n0/100\n\n## Feedback\nScore parsing failed — manual review required\n\nRaw Output:\n#{dispatch_result.result}"
      end

      @execution.workflow_run.artifacts.create!(
        artifact_type: :score_report,
        name: "Score Report #{@execution.workflow_run.artifacts.count + 1}",
        content: content,
        project_id: @execution.workflow_run.project_id,
        created_by: @execution.workflow_run.project.agent_teams.first,
        metadata: { score: score, parser_message: message }
      )
    end

    def create_error_artifact(error)
      @execution.workflow_run.artifacts.create!(
        artifact_type: :score_report,
        name: "Score Report (Error) #{@execution.workflow_run.artifacts.count + 1}",
        content: "Score evaluation failed: #{error.message}",
        project_id: @execution.workflow_run.project_id,
        created_by: @execution.workflow_run.project.agent_teams.first,
        metadata: { error: error.class.name, error_message: error.message }
      )
    end
  end

  QualityGate.register(QaGate)
end
