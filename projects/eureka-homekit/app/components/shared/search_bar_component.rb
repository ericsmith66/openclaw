# frozen_string_literal: true

class Shared::SearchBarComponent < ViewComponent::Base
  def initialize(placeholder: "Search...", name: "query", value: nil, url: nil)
    @placeholder = placeholder
    @name = name
    @value = value
    @url = url
  end
end
