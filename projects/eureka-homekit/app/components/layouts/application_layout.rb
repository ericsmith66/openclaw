# frozen_string_literal: true

class Layouts::ApplicationLayout < ViewComponent::Base
  def initialize(title: "Eureka Dashboard", homes: [], grouped_events: [], sidebar_title: "Recent Activity", sync_status: :success, last_sync: nil)
    @title = title
    @homes = homes
    @grouped_events = grouped_events
    @sidebar_title = sidebar_title
    @sync_status = sync_status
    @last_sync = last_sync
  end
end
