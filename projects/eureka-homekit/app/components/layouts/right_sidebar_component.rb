# frozen_string_literal: true

class Layouts::RightSidebarComponent < ViewComponent::Base
  def initialize(grouped_events: [], title: "Recent Activity", context_type: nil, context_id: nil)
    @grouped_events = grouped_events
    @title = title
    @context_type = context_type
    @context_id = context_id
  end
end
