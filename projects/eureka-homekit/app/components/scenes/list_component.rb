# frozen_string_literal: true

module Scenes
  class ListComponent < ViewComponent::Base
    def initialize(scenes:, show_home: false)
      @scenes = scenes
      @show_home = show_home
    end

    def grouped_scenes
      @scenes.group_by { |s| s.home.name }
    end

    def empty?
      @scenes.empty?
    end

    def show_home?
      @show_home
    end

    def should_group?
      @show_home && grouped_scenes.keys.size > 1
    end
  end
end
