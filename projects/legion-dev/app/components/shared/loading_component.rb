# frozen_string_literal: true

class Shared::LoadingComponent < ViewComponent::Base
  def initialize(size: :md, color: :primary)
    @size = size
    @color = color
  end

  def size_class
    case @size.to_sym
    when :xs then "loading-xs"
    when :sm then "loading-sm"
    when :lg then "loading-lg"
    else "loading-md"
    end
  end

  def color_class
    "text-#{@color}"
  end
end
