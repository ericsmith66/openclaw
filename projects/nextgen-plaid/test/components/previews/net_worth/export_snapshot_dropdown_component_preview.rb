# frozen_string_literal: true

module NetWorth
  class ExportSnapshotDropdownComponentPreview < ViewComponent::Preview
    def enabled
      snapshot = FinancialSnapshot.new(id: 123, snapshot_at: Time.zone.today)
      render NetWorth::ExportSnapshotDropdownComponent.new(snapshot: snapshot)
    end

    def disabled_empty_snapshot
      render NetWorth::ExportSnapshotDropdownComponent.new(snapshot: nil)
    end
  end
end
