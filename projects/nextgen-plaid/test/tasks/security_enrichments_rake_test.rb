require "test_helper"
require "rake"

class SecurityEnrichmentsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["security_enrichments:cleanup_finnhub_and_dedupe"].reenable
  end

  test "deletes finnhub rows and dedupes duplicates by security_id" do
    security_id = "sec_cleanup"

    conn = ActiveRecord::Base.connection

    # The cleanup task is intended to run *before* adding the unique index.
    # In test, the current schema may already have the unique index on `security_id`,
    # so we temporarily drop it to simulate pre-index production state.
    begin
      conn.remove_index(:security_enrichments, :security_id)
    rescue ArgumentError
      # index not present
    end

    now = Time.current
    conn.execute(
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [
          "INSERT INTO security_enrichments (security_id, source, enriched_at, status, data, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          security_id,
          "finnhub",
          now - 5.days,
          "success",
          {}.to_json,
          [].to_json,
          now,
          now
        ]
      )
    )

    conn.execute(
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [
          "INSERT INTO security_enrichments (security_id, source, enriched_at, status, data, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          security_id,
          "fmp",
          now - 2.days,
          "success",
          { v: 1 }.to_json,
          [].to_json,
          now,
          now
        ]
      )
    )

    conn.execute(
      ActiveRecord::Base.send(
        :sanitize_sql_array,
        [
          "INSERT INTO security_enrichments (security_id, source, enriched_at, status, data, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          security_id,
          "fmp",
          now - 1.day,
          "success",
          { v: 2 }.to_json,
          [].to_json,
          now,
          now
        ]
      )
    )

    out, _err = capture_io do
      Rake::Task["security_enrichments:cleanup_finnhub_and_dedupe"].invoke
    end

    assert_includes out, "Deleted finnhub records: 1"
    assert_includes out, "Duplicate security_ids processed: 1"

    assert_equal 1, SecurityEnrichment.where(security_id: security_id).count
    assert_equal 0, SecurityEnrichment.where(source: "finnhub").count
  ensure
    # Put schema back the way the app expects.
    begin
      conn.add_index(:security_enrichments, :security_id, unique: true)
    rescue ArgumentError
      # already exists
    end
  end
end
