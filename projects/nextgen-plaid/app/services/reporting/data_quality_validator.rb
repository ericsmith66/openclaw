# frozen_string_literal: true

module Reporting
  class DataQualityValidator
    def initialize(financial_snapshot)
      @financial_snapshot = financial_snapshot
    end

    # Minimal implementation for PRD-2-01.
    # Future PRDs can extend this to compute weighted scores.
    def score
      stored = @financial_snapshot.data&.dig("data_quality", "score")
      return stored.to_f if stored != nil

      0.0
    end
  end
end
