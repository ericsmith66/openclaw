# frozen_string_literal: true

class Shared::ModalComponent < ViewComponent::Base
  renders_one :title
  renders_one :footer

  def initialize(id:)
    @id = id
  end
end
