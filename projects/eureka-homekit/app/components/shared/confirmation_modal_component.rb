module Shared
  class ConfirmationModalComponent < ViewComponent::Base
    def initialize(title:, description:, confirm_text: "Confirm", cancel_text: "Cancel", confirm_type: :warning, cancel_type: :ghost)
      @title = title
      @description = description
      @confirm_text = confirm_text
      @cancel_text = cancel_text
      @confirm_type = confirm_type
      @cancel_type = cancel_type
    end

    def confirm_classes
      case @confirm_type
      when :danger then "btn btn-error"
      when :warning then "btn btn-warning"
      when :primary then "btn btn-primary"
      else "btn"
      end
    end

    def cancel_classes
      case @cancel_type
      when :secondary then "btn btn-secondary"
      else "btn"
      end
    end
  end
end
