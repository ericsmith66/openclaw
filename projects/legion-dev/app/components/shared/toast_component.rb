# frozen_string_literal: true

class Shared::ToastComponent < ViewComponent::Base
  def initialize(message:, type: :info)
    @message = message
    @type = type
  end

  def alert_class
    case @type.to_sym
    when :success
      "alert-success"
    when :error
      "alert-error"
    when :warning
      "alert-warning"
    else
      "alert-info"
    end
  end
end
