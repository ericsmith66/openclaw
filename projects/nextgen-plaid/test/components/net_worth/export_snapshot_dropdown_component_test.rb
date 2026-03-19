# frozen_string_literal: true

require "test_helper"

class NetWorthExportSnapshotDropdownComponentTest < ViewComponent::TestCase
  test "renders enabled dropdown when snapshot present" do
    snapshot = FinancialSnapshot.new(id: 1, snapshot_at: Time.zone.today)

    render_inline(NetWorth::ExportSnapshotDropdownComponent.new(snapshot: snapshot))

    assert_selector "[aria-label='Export snapshot']", text: "Export Snapshot"
    assert_selector "a", text: "Download JSON (summary)"
    assert_selector "a", text: "Download JSON (full)"
    assert_selector "a", text: "Download CSV"
  end

  test "renders disabled button when snapshot missing" do
    render_inline(NetWorth::ExportSnapshotDropdownComponent.new(snapshot: nil))

    assert_selector "button[disabled]", text: "Export Snapshot"
  end
end
