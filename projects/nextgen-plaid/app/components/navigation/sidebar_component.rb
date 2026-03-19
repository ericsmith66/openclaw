# frozen_string_literal: true

module Navigation
  class SidebarComponent < ViewComponent::Base
    def initialize(current_user:, drawer_id:)
      @current_user = current_user
      @drawer_id = drawer_id
    end

    def owner?
      @current_user&.owner?
    end

    def close_drawer_js
      "document.getElementById('#{@drawer_id}').checked = false"
    end
  end
end
