module Controls
  class ColorPickerComponent < ViewComponent::Base
    def initialize(accessory: nil, current_hue: 0, current_saturation: 100, hue: nil, saturation: nil, offline: false)
      @accessory = accessory
      @hue = current_hue || hue || 0
      @saturation = current_saturation || saturation || 100
      @offline = offline
    end

    def current_hue
      @hue
    end

    def current_saturation
      @saturation
    end

    def preview_color
      "hsl(#{@hue}, #{@saturation}%, 50%)"
    end

    def offline?
      @offline
    end
  end
end
