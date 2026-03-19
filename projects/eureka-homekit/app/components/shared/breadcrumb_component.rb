# frozen_string_literal: true

class Shared::BreadcrumbComponent < ViewComponent::Base
  def initialize(items:)
    @items = items # Array of hashes: { label: "Home", path: root_path, current: false }
  end
end
