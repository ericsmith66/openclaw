# frozen_string_literal: true

class Shared::StatusBadgeComponent < ViewComponent::Base
  def initialize(status:, pulse: false, label: nil, size: :md)
    @status = status.to_sym
    @pulse = pulse
    @label = label || status.to_s.capitalize
    @size = size
  end

  def badge_classes
    classes = [ "badge", "gap-2" ]
    classes << status_class
    classes << size_class
    classes << "animate-pulse" if @pulse
    classes.join(" ")
  end

  private

  def size_class
    case @size
    when :xs then "badge-xs"
    when :sm then "badge-sm"
    when :lg then "badge-lg"
    else ""
    end
  end

  def status_class
    case @status
    when :success, :online, :ok
      "badge-success"
    when :warning, :syncing
      "badge-warning"
    when :danger, :error, :offline, :critical
      "badge-error"
    when :info
      "badge-info"
    else
      "badge-ghost"
    end
  end
end
