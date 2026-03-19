# frozen_string_literal: true

module Shared
  class MultiSelectComponent < ViewComponent::Base
    def initialize(items:, id_method: :uuid, label_method: :name, selected: [])
      @items = items
      @id_method = id_method
      @label_method = label_method
      @selected = selected
    end

    def item_id(item)
      item.public_send(@id_method)
    end

    def item_label(item)
      item.public_send(@label_method)
    end

    def selected?(item)
      @selected.include?(item_id(item))
    end

    def items_count
      @items.size
    end

    def selected_count
      @selected.size
    end
  end
end
