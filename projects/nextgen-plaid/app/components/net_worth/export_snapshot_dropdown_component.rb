# frozen_string_literal: true

module NetWorth
  class ExportSnapshotDropdownComponent < ViewComponent::Base
    def initialize(snapshot: nil)
      @snapshot = snapshot
    end

    attr_reader :snapshot

    def enabled?
      snapshot.present?
    end
  end
end
