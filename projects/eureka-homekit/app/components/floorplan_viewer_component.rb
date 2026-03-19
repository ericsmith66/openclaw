class FloorplanViewerComponent < ViewComponent::Base
  def initialize(home:)
    @home = home
    @floorplans = @home.floorplans.order(:level)
    @active_floorplan = @floorplans.first
  end

  def render?
    @floorplans.any?
  end
end
