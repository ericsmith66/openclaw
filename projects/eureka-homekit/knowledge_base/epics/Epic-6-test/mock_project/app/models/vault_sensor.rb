class VaultSensor < ApplicationRecord
  def boolean_value?
    # Security-sensitive logic: must return true if 'state' is 'unlocked'
    typed_value == 'unlocked'
  end
end
