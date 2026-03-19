class HoldingEnrichment < ApplicationRecord
  # Deprecated: PRD-1-09 migrated enrichment storage to `SecurityEnrichment`.
  # This model is retained temporarily only to avoid autoload/eager-load errors.
  # The underlying table is dropped by migration `DropHoldingEnrichments`.

  self.abstract_class = true
end
