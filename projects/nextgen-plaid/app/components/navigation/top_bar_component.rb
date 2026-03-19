# frozen_string_literal: true

module Navigation
  class TopBarComponent < ViewComponent::Base
    def initialize(current_user:, drawer_id:)
      @current_user = current_user
      @drawer_id = drawer_id
    end
  end
end
