class SyncsController < ApplicationController
  def create
    cleanup = params[:cleanup] == "true"
    summary = HomekitSync.new.perform(cleanup: cleanup)
    if summary[:sync_skipped]
      notice = "Sync skipped (#{summary[:sync_reason]}). Existing data preserved."
      notice += " Cleanup skipped (#{summary[:cleanup_reason]})." if summary[:cleanup_skipped]
    else
      notice = "Sync complete! Added #{summary[:homes]} homes, #{summary[:rooms]} rooms, #{summary[:accessories]} accessories."
      notice += " Sync retry succeeded." if summary[:sync_retried]
      notice += " Deleted #{summary[:deleted]} stale records." if cleanup && summary[:deleted] > 0
      notice += " Cleanup skipped (#{summary[:cleanup_reason]})." if summary[:cleanup_skipped]
    end
    redirect_back fallback_location: root_path, notice: notice
  end
end
