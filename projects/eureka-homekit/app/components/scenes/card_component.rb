class Scenes::CardComponent < ViewComponent::Base
  def initialize(scene:, show_home: false)
    @scene = scene
    @show_home = show_home
  end

  def icon_emoji
    # Map scene names to emojis (basic heuristic)
    case @scene.name.downcase
    when /morning/, /wake/
      "🌅"
    when /night/, /sleep/, /bed/
      "🌙"
    when /movie/, /tv/
      "🎬"
    when /dinner/, /eat/
      "🍽️"
    when /leave/, /away/
      "🚪"
    when /arrive/, /home/
      "🏠"
    else
      "⚡" # default
    end
  end

  def accessories_count
    @scene.accessories.count
  end

  def last_executed
    last_event = ControlEvent.for_scene(@scene.id).successful.order(created_at: :desc).first
    last_event ? time_ago_in_words(last_event.created_at) : "Never"
  end
end
