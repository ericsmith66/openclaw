# frozen_string_literal: true

class NetWorthHeroComponent < ViewComponent::Base
  def initialize(data:)
    @data = data.to_h
  end
end
