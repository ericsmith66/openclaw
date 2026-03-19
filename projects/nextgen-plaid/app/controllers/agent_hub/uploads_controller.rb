class AgentHub::UploadsController < ApplicationController
  before_action :authenticate_user!

  def create
    run = AiWorkflowRun.for_user(current_user).find(params[:run_id])
    files = params[:files]

    if files.present?
      begin
        # Ensure it's an array for has_many_attached
        files = Array(files)
        files.each do |file|
          run.attachments.attach(file)
        end
        run.save!
      rescue StandardError => e
        Rails.logger.error "Error attaching files: #{e.message}"
        render json: { success: false, error: e.message }, status: :internal_server_error and return
      end

      # Reload the run to get the fresh attachments with IDs
      run.reload
      attachment_data = run.attachments.last(files.size).map do |attachment|
        {
          id: attachment.id,
          filename: attachment.filename.to_s,
          url: url_for(attachment)
        }
      end

      render json: { success: true, attachments: attachment_data }
    else
      render json: { success: false, error: "No files provided" }, status: :unprocessable_entity
    end
  end
end
