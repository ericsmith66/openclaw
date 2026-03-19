# frozen_string_literal: true

require "rails_helper"

RSpec.describe TemperatureConverter do
  describe ".to_fahrenheit" do
    it "converts 0°C to 32°F" do
      expect(described_class.to_fahrenheit(0)).to eq(32.0)
    end

    it "converts 100°C to 212°F" do
      expect(described_class.to_fahrenheit(100)).to eq(212.0)
    end

    it "converts 22°C to 71.6°F" do
      expect(described_class.to_fahrenheit(22)).to eq(71.6)
    end

    it "converts -10°C to 14°F" do
      expect(described_class.to_fahrenheit(-10)).to eq(14.0)
    end

    it "rounds to 1 decimal place" do
      expect(described_class.to_fahrenheit(20.5)).to eq(68.9)
    end
  end

  describe ".to_celsius" do
    it "converts 32°F to 0°C" do
      expect(described_class.to_celsius(32)).to eq(0.0)
    end

    it "converts 212°F to 100°C" do
      expect(described_class.to_celsius(212)).to eq(100.0)
    end

    it "converts 72°F to 22.2°C" do
      expect(described_class.to_celsius(72)).to eq(22.2)
    end

    it "converts 0°F to -17.8°C" do
      expect(described_class.to_celsius(0)).to eq(-17.8)
    end

    it "rounds to 1 decimal place" do
      expect(described_class.to_celsius(68.5)).to eq(20.3)
    end
  end

  describe ".convert" do
    it "converts C to F" do
      expect(described_class.convert(20, 'C', 'F')).to eq(68.0)
    end

    it "converts F to C" do
      expect(described_class.convert(68, 'F', 'C')).to eq(20.0)
    end

    it "returns value unchanged when units match" do
      expect(described_class.convert(20, 'C', 'C')).to eq(20)
      expect(described_class.convert(68, 'F', 'F')).to eq(68)
    end

    it "handles unknown unit gracefully" do
      expect(described_class.convert(20, 'X', 'F')).to eq(20)
    end
  end
end
