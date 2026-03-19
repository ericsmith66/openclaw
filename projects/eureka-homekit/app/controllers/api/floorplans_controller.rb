class Api::FloorplansController < ApplicationController
  def show
    @floorplan = Floorplan.find(params[:id])

    mapping_service = FloorplanMappingService.new(@floorplan)
    resolved_mapping = mapping_service.resolve

    render json: {
      id: @floorplan.id,
      name: @floorplan.name,
      level: @floorplan.level,
      svg_url: @floorplan.svg_file.attached? ? url_for(@floorplan.svg_file) : nil,
      svg_content: @floorplan.svg_file.attached? ? @floorplan.svg_file.download.force_encoding("UTF-8") : nil,
      mapping: resolved_mapping.transform_values { |v| format_resolved_room(v) }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Floorplan not found" }, status: :not_found
  end

  private

  def format_resolved_room(data)
    return data if data[:error]

    {
      room_id: data[:room].id,
      room_name: data[:room].name,
      sensor_states: data[:sensor_states],
      heatmap_class: helpers.room_heatmap_class(data[:room])
    }
  end
end
