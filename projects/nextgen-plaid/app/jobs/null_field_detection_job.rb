# app/jobs/null_field_detection_job.rb
class NullFieldDetectionJob < ApplicationJob
  queue_as :default

  DEFAULT_OUTPUT_PATH = Rails.root.join("knowledge_base", "schemas", "null_fields_report.md").freeze
  PATTERN_THRESHOLD = 0.95

  def perform(output_path = nil)
    output_path ||= DEFAULT_OUTPUT_PATH

    results = {
      accounts: aggregate_accounts,
      holdings: aggregate_holdings,
      transactions: aggregate_transactions,
      liabilities: aggregate_liabilities,
      balance_snapshots: aggregate_balance_snapshots
    }

    report = build_report(results)
    write_report(output_path, report)
    log_patterns(results)
  end

  private

  def aggregate_holdings
    relation = Holding.joins(account: :plaid_item)
    excluded = %w[id created_at updated_at account_id]
    columns = (Holding.column_names - excluded)

    aggregate_nulls(
      relation: relation,
      table_name: Holding.table_name,
      columns: columns
    )
  end

  def aggregate_accounts
    relation = Account.joins(:plaid_item)
    columns = %w[official_name credit_limit holder_category]

    aggregate_nulls(
      relation: relation,
      table_name: Account.table_name,
      columns: columns
    )
  end

  def aggregate_transactions
    relation = Transaction.joins(account: :plaid_item)
    excluded = %w[id created_at updated_at account_id]
    columns = (Transaction.column_names - excluded)

    aggregate_nulls(
      relation: relation,
      table_name: Transaction.table_name,
      columns: columns
    )
  end

  def aggregate_balance_snapshots
    relation = AccountBalanceSnapshot.joins(account: :plaid_item)
    excluded = %w[id created_at updated_at account_id]
    columns = (AccountBalanceSnapshot.column_names - excluded)

    aggregate_nulls(
      relation: relation,
      table_name: AccountBalanceSnapshot.table_name,
      columns: columns
    )
  end

  # There is no standalone Liability model in this repo; liability data is stored on Account.
  def aggregate_liabilities
    base = Account.joins(:plaid_item)

    # Restrict to accounts that are likely liabilities (to avoid noise from depository/investment accounts).
    relation = base.where(type: %w[credit loan]).or(base.where.not(liability_details: nil))

    columns = %w[
      apr_percentage
      min_payment_amount
      next_payment_due_date
      is_overdue
      debt_risk_flag
      liability_details
    ]

    aggregate_nulls(
      relation: relation,
      table_name: Account.table_name,
      columns: columns
    )
  end

  def aggregate_nulls(relation:, table_name:, columns:)
    connection = ActiveRecord::Base.connection
    quoted_table = connection.quote_table_name(table_name)

    selects = [
      "plaid_items.institution_id AS institution_id",
      "COUNT(*) AS total_count"
    ]

    columns.each do |col|
      quoted_col = connection.quote_column_name(col)
      alias_name = connection.quote_column_name("#{col}_nulls")
      selects << "SUM(CASE WHEN #{quoted_table}.#{quoted_col} IS NULL THEN 1 ELSE 0 END) AS #{alias_name}"
    end

    rows = connection.select_all(
      relation
        .group("plaid_items.institution_id")
        .select(Arel.sql(selects.join(", ")))
        .to_sql
    ).to_a

    rows.each_with_object({}) do |row, h|
      institution_id = row["institution_id"].presence || "UNKNOWN"
      total = row["total_count"].to_i

      nulls = columns.each_with_object({}) do |col, col_h|
        col_h[col] = row["#{col}_nulls"].to_i
      end

      h[institution_id] = { total: total, nulls: nulls }
    end
  end

  def build_report(results)
    timestamp = Time.current
    institutions = results.values.flat_map(&:keys).uniq.sort

    lines = []
    lines << "# Null Fields Report"
    lines << ""
    lines << "Generated at: #{timestamp.iso8601}"
    lines << ""
    lines << "This report scans Accounts, Holdings, Transactions, Liabilities (stored on Accounts), and Balance Snapshots for null fields, grouped by Plaid institution_id."
    lines << ""

    if institutions.empty?
      lines << "No data found (no holdings/transactions/liability accounts in the database)."
      lines << ""
      return lines.join("\n")
    end

    institutions.each do |institution_id|
      lines << "---"
      lines << ""
      lines << "## Institution: #{institution_id}"
      lines << ""

      append_model_section(lines, "Accounts", results[:accounts][institution_id])
      append_model_section(lines, "Holdings", results[:holdings][institution_id])
      append_model_section(lines, "Transactions", results[:transactions][institution_id])
      append_model_section(lines, "Liabilities (Accounts)", results[:liabilities][institution_id])
      append_model_section(lines, "Balance Snapshots", results[:balance_snapshots][institution_id])
    end

    lines.join("\n")
  end

  def append_model_section(lines, title, data)
    lines << "### #{title}"
    lines << ""

    if data.blank? || data[:total].to_i == 0
      lines << "- Total rows: 0"
      lines << "- No rows to analyze."
      lines << ""
      return
    end

    total = data[:total].to_i
    lines << "- Total rows: #{total}"
    lines << ""
    lines << "| Field | Null Count | Null % | Pattern |"
    lines << "| --- | ---: | ---: | --- |"

    rows = data[:nulls]
      .select { |_field, null_count| null_count.to_i > 0 }
      .map do |field, null_count|
        null_count = null_count.to_i
        ratio = total > 0 ? (null_count.to_f / total) : 0.0
        pattern = if ratio == 1.0
          "always null"
        elsif ratio >= PATTERN_THRESHOLD
          "mostly null"
        else
          ""
        end

        [ field, null_count, ratio, pattern ]
      end
      .sort_by { |(_field, null_count, ratio, _pattern)| [ -ratio, -null_count ] }

    if rows.empty?
      lines << "| (none) | 0 | 0% | |"
      lines << ""
      return
    end

    rows.each do |field, null_count, ratio, pattern|
      percent = (ratio * 100).round(2)
      lines << "| `#{field}` | #{null_count} | #{percent}% | #{pattern} |"
    end
    lines << ""
  end

  def write_report(output_path, report)
    path = output_path.is_a?(Pathname) ? output_path : Pathname.new(output_path.to_s)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, report)
  end

  def log_patterns(results)
    results.each do |model_name, model_results|
      model_results.each do |institution_id, data|
        total = data[:total].to_i
        next if total <= 0

        data[:nulls].each do |field, null_count|
          null_count = null_count.to_i
          next if null_count <= 0

          ratio = null_count.to_f / total
          next unless ratio >= PATTERN_THRESHOLD

          pattern = ratio == 1.0 ? "always null" : "mostly null"
          Rails.logger.warn(
            "NullFieldDetectionJob: institution=#{institution_id} model=#{model_name} field=#{field} #{pattern} (#{null_count}/#{total})"
          )
        end
      end
    end
  end
end
