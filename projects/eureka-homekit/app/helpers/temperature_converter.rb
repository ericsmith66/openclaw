module TemperatureConverter
  C_TO_F = lambda { |c| (c * 9.0 / 5.0) + 32.0 }
  F_TO_C = lambda { |f| (f - 32.0) * 5.0 / 9.0 }

  def self.to_fahrenheit(celsius)
    C_TO_F.call(celsius).round(1)
  end

  def self.to_celsius(fahrenheit)
    F_TO_C.call(fahrenheit).round(1)
  end

  def self.convert(value, from_unit, to_unit)
    return value if from_unit == to_unit

    if from_unit == "C" && to_unit == "F"
      to_fahrenheit(value)
    elsif from_unit == "F" && to_unit == "C"
      to_celsius(value)
    else
      value
    end
  end
end
