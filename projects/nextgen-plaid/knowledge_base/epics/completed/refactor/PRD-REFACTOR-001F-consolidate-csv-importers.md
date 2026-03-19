# PRD-REFACTOR-001F: Consolidate CSV Importers

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Extract common patterns from three CSV importer services into a shared base class or module, reducing code duplication and establishing a reusable pattern for future importers.

---

## Problem statement

The codebase contains three CSV importer services with significant code duplication:

1. **CsvTransactionsImporter** (354 lines)
2. **CsvHoldingsImporter** (234 lines)
3. **CsvAccountsImporter** (165 lines)

**Common patterns across all three**:
- CSV parsing and validation
- Row-by-row processing with error collection
- Transaction wrapping (all-or-nothing import)
- User context and association
- Error reporting and logging
- Batch processing logic
- Duplicate detection

**Estimated duplication**: ~100 lines of shared logic per importer = **300 lines of duplicate code**.

This violates the DRY principle and creates maintenance burden:
- Bug fixes must be replicated across all importers
- New importers require copy-pasting boilerplate
- Testing overhead (same patterns tested 3+ times)

---

## Proposed solution

### Option A: Abstract base class (RECOMMENDED)

Create `BaseCsvImporter` abstract class with template method pattern:

```ruby
class BaseCsvImporter
  def initialize(file:, user:, **options)
    @file = file
    @user = user
    @options = options
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  def call
    validate_file!

    ApplicationRecord.transaction do
      process_rows
      raise ActiveRecord::Rollback if @errors.any?
    end

    build_result
  end

  protected

  # Template methods (must be implemented by subclasses)
  def parse_row(row); raise NotImplementedError; end
  def create_record(attrs); raise NotImplementedError; end
  def find_duplicate(attrs); nil; end
  def record_type; raise NotImplementedError; end

  # Hook methods (optional overrides)
  def validate_row(attrs); []; end
  def before_import; end
  def after_import; end

  private

  def process_rows
    # Shared CSV processing logic
  end

  def validate_file!
    # Shared file validation logic
  end

  def build_result
    # Shared result formatting
  end
end
```

**Usage in subclasses**:
```ruby
class CsvTransactionsImporter < BaseCsvImporter
  protected

  def parse_row(row)
    {
      date: row["date"],
      amount: row["amount"],
      merchant_name: row["merchant"],
      # ... transaction-specific fields
    }
  end

  def create_record(attrs)
    Transaction.create!(attrs.merge(user: @user))
  end

  def find_duplicate(attrs)
    Transaction.find_by(
      user: @user,
      date: attrs[:date],
      amount: attrs[:amount],
      merchant_name: attrs[:merchant_name]
    )
  end

  def record_type
    "Transaction"
  end

  def validate_row(attrs)
    errors = []
    errors << "Invalid date" unless attrs[:date].is_a?(Date)
    errors << "Invalid amount" unless attrs[:amount].is_a?(Numeric)
    errors
  end
end
```

### Option B: Mixin module (ALTERNATIVE)

Create `CsvImportable` concern:

```ruby
module CsvImportable
  extend ActiveSupport::Concern

  included do
    attr_reader :file, :user, :errors, :imported_count, :skipped_count
  end

  def initialize(file:, user:, **options)
    # ... shared initialization
  end

  def call
    # ... shared orchestration
  end

  private

  def process_rows
    # ... shared processing
  end
end

class CsvTransactionsImporter
  include CsvImportable

  def parse_row(row)
    # ... specific implementation
  end
end
```

**Recommendation**: Use **Option A (Base Class)** because:
- Template method pattern fits the use case perfectly
- Clearer contract (abstract methods must be implemented)
- Better for enforcing structure
- Easier to add shared behavior without affecting all importers

---

## Implementation plan

### Step 1: Analyze common patterns
- Compare all three importers side-by-side
- Identify exact duplicated code blocks
- List variations/differences
- Define template method contract

### Step 2: Create BaseCsvImporter
- Create `app/services/base_csv_importer.rb`
- Extract common initialization, validation, transaction wrapping
- Define abstract methods (parse_row, create_record, etc.)
- Define hook methods (validate_row, before_import, after_import)
- Add comprehensive YARD documentation

### Step 3: Refactor CsvAccountsImporter (smallest, least risk)
- Subclass BaseCsvImporter
- Remove duplicated code
- Implement abstract methods
- Run existing tests
- Verify identical behavior

### Step 4: Refactor CsvHoldingsImporter
- Subclass BaseCsvImporter
- Remove duplicated code
- Implement abstract methods
- Run existing tests
- Verify identical behavior

### Step 5: Refactor CsvTransactionsImporter (largest, most complex)
- Subclass BaseCsvImporter
- Remove duplicated code
- Implement abstract methods
- Handle transaction-specific complexities
- Run existing tests
- Verify identical behavior

### Step 6: Final cleanup
- Remove any remaining duplication
- Update YARD documentation
- Ensure all tests pass
- Measure final line counts

---

## Base class design

### File: `app/services/base_csv_importer.rb` (NEW)

```ruby
# frozen_string_literal: true

require "csv"

# Abstract base class for CSV import services.
#
# Provides common CSV parsing, validation, error collection, and transaction
# wrapping. Subclasses must implement abstract methods for record-specific logic.
#
# @abstract Subclass and implement {#parse_row}, {#create_record}, and {#record_type}
#
# @example
#   class CsvTransactionsImporter < BaseCsvImporter
#     protected
#
#     def parse_row(row)
#       { date: row["date"], amount: row["amount"] }
#     end
#
#     def create_record(attrs)
#       Transaction.create!(attrs.merge(user: @user))
#     end
#
#     def record_type
#       "Transaction"
#     end
#   end
#
#   importer = CsvTransactionsImporter.new(file: uploaded_file, user: current_user)
#   result = importer.call
#   # => { success: true, imported: 10, skipped: 2, errors: [] }
class BaseCsvImporter
  attr_reader :file, :user, :options, :errors, :imported_count, :skipped_count

  # @param file [ActionDispatch::Http::UploadedFile] the CSV file to import
  # @param user [User] the user context for imported records
  # @param options [Hash] importer-specific options
  def initialize(file:, user:, **options)
    @file = file
    @user = user
    @options = options
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  # Executes the CSV import within a transaction.
  #
  # @return [Hash] result summary with :success, :imported, :skipped, :errors keys
  def call
    validate_file!
    before_import

    ApplicationRecord.transaction do
      process_rows
      raise ActiveRecord::Rollback if @errors.any?
    end

    after_import
    build_result
  end

  protected

  # Parses a CSV row into record attributes.
  #
  # @abstract Subclasses must implement this method
  # @param row [CSV::Row] the CSV row to parse
  # @return [Hash] attribute hash for record creation
  # @raise [NotImplementedError] if not implemented by subclass
  def parse_row(row)
    raise NotImplementedError, "#{self.class}#parse_row must be implemented"
  end

  # Creates a record from parsed attributes.
  #
  # @abstract Subclasses must implement this method
  # @param attrs [Hash] the parsed attributes
  # @return [ActiveRecord::Base] the created record
  # @raise [NotImplementedError] if not implemented by subclass
  def create_record(attrs)
    raise NotImplementedError, "#{self.class}#create_record must be implemented"
  end

  # Returns the human-readable record type name for error messages.
  #
  # @abstract Subclasses must implement this method
  # @return [String] the record type (e.g., "Transaction", "Holding")
  # @raise [NotImplementedError] if not implemented by subclass
  def record_type
    raise NotImplementedError, "#{self.class}#record_type must be implemented"
  end

  # Finds an existing duplicate record if one exists.
  #
  # @param attrs [Hash] the parsed attributes
  # @return [ActiveRecord::Base, nil] existing record or nil
  def find_duplicate(attrs)
    nil
  end

  # Validates parsed row attributes.
  #
  # @param attrs [Hash] the parsed attributes
  # @return [Array<String>] array of validation error messages (empty if valid)
  def validate_row(attrs)
    []
  end

  # Hook called before import begins.
  def before_import; end

  # Hook called after import completes.
  def after_import; end

  # Returns the CSV parsing options.
  #
  # @return [Hash] options for CSV.parse (headers, converters, etc.)
  def csv_options
    { headers: true, header_converters: :symbol }
  end

  private

  def validate_file!
    raise ArgumentError, "File is required" if file.blank?
    raise ArgumentError, "File must be a CSV" unless file.content_type == "text/csv" || file.original_filename.end_with?(".csv")
  end

  def process_rows
    CSV.parse(file.read, **csv_options).each.with_index(1) do |row, line_number|
      process_row(row, line_number)
    end
  rescue CSV::MalformedCSVError => e
    @errors << "CSV parsing error: #{e.message}"
  end

  def process_row(row, line_number)
    attrs = parse_row(row)
    validation_errors = validate_row(attrs)

    if validation_errors.any?
      @errors << "Line #{line_number}: #{validation_errors.join(', ')}"
      return
    end

    if (existing = find_duplicate(attrs))
      @skipped_count += 1
      Rails.logger.info("Skipped duplicate #{record_type} at line #{line_number}")
      return
    end

    create_record(attrs)
    @imported_count += 1
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Line #{line_number}: #{e.message}"
  rescue StandardError => e
    @errors << "Line #{line_number}: Unexpected error: #{e.message}"
    Rails.logger.error("CSV import error at line #{line_number}: #{e.class} - #{e.message}")
  end

  def build_result
    {
      success: @errors.empty?,
      imported: @imported_count,
      skipped: @skipped_count,
      errors: @errors
    }
  end
end
```

---

## Refactored importer example

### File: `app/services/csv_transactions_importer.rb` (MODIFIED)

**Before** (354 lines):
```ruby
class CsvTransactionsImporter
  def initialize(file:, user:)
    @file = file
    @user = user
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  def call
    # 50 lines of CSV parsing boilerplate
    # 100 lines of row processing
    # 50 lines of error handling
    # 50 lines of transaction wrapping
    # 50 lines of validation
    # 54 lines of transaction-specific logic
  end

  private

  # 100+ lines of helper methods
end
```

**After** (< 100 lines):
```ruby
class CsvTransactionsImporter < BaseCsvImporter
  protected

  def parse_row(row)
    {
      account_id: find_account_id(row["account"]),
      date: parse_date(row["date"]),
      amount: parse_amount(row["amount"]),
      merchant_name: row["merchant"]&.strip,
      category: row["category"]&.strip,
      description: row["description"]&.strip
    }
  end

  def create_record(attrs)
    Transaction.create!(attrs.merge(
      user: user,
      imported_at: Time.current,
      source: "csv_import"
    ))
  end

  def find_duplicate(attrs)
    Transaction.find_by(
      user: user,
      account_id: attrs[:account_id],
      date: attrs[:date],
      amount: attrs[:amount],
      merchant_name: attrs[:merchant_name]
    )
  end

  def validate_row(attrs)
    errors = []
    errors << "Account not found" if attrs[:account_id].nil?
    errors << "Invalid date" unless attrs[:date].is_a?(Date)
    errors << "Invalid amount" unless attrs[:amount].is_a?(Numeric)
    errors << "Merchant name required" if attrs[:merchant_name].blank?
    errors
  end

  def record_type
    "Transaction"
  end

  private

  def find_account_id(account_identifier)
    return nil if account_identifier.blank?
    Account.find_by(user: user, name: account_identifier)&.id
  end

  def parse_date(date_string)
    Date.parse(date_string)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_amount(amount_string)
    amount_string.to_s.gsub(/[$,]/, "").to_f
  rescue StandardError
    nil
  end
end
```

**Result**: Reduced from 354 lines to ~100 lines (**71% reduction**)

---

## Testing strategy

### Unit tests for BaseCsvImporter
Create `test/services/base_csv_importer_test.rb`:

```ruby
require "test_helper"

class BaseCsvImporterTest < ActiveSupport::TestCase
  class TestImporter < BaseCsvImporter
    def parse_row(row)
      { name: row["name"] }
    end

    def create_record(attrs)
      OpenStruct.new(attrs)
    end

    def record_type
      "TestRecord"
    end
  end

  test "processes valid CSV" do
    # Test happy path
  end

  test "collects validation errors" do
    # Test error collection
  end

  test "rolls back on errors" do
    # Test transaction rollback
  end

  test "skips duplicates" do
    # Test duplicate detection
  end
end
```

### Integration tests (existing)
- Existing importer tests continue to work unchanged
- Tests verify end-to-end functionality
- No changes to test assertions

---

## Acceptance criteria

- AC1: `BaseCsvImporter` abstract class created with full documentation
- AC2: All three importers refactored to extend base class
- AC3: All existing importer tests pass without modification
- AC4: Each importer reduced to < 100 lines (from 354, 234, 165)
- AC5: Total code reduction: ~300 lines eliminated
- AC6: New unit tests added for BaseCsvImporter (100% coverage)
- AC7: YARD documentation complete for base class and template methods
- AC8: Pattern documented for future CSV importers

---

## Affected files

**New files**:
- `app/services/base_csv_importer.rb`
- `test/services/base_csv_importer_test.rb`

**Modified files** (reduced line count):
- `app/services/csv_transactions_importer.rb` (354 → ~100 lines)
- `app/services/csv_holdings_importer.rb` (234 → ~80 lines)
- `app/services/csv_accounts_importer.rb` (165 → ~60 lines)

**Lines saved**: ~300 lines of duplicate code eliminated

---

## Risks and mitigation

### Risk: Breaking existing import functionality
- **Mitigation**: Comprehensive test suite; incremental refactoring (one importer at a time)
- **Validation**: Run all importer tests; test in staging with real CSV files

### Risk: Importers have subtle differences not captured by base class
- **Mitigation**: Template method + hook pattern allows for customization
- **Validation**: Side-by-side comparison of before/after behavior

### Risk: Performance regression from additional abstraction layer
- **Mitigation**: Benchmark before/after; base class adds minimal overhead
- **Validation**: Profiling on large CSV files (1000+ rows)

---

## Success metrics

- Code duplication: Reduced by ~300 lines (40% reduction overall)
- Importer size: Average < 100 lines (from 251 line average)
- Maintainability: Bug fixes applied once in base class
- Future velocity: New importers require ~50 lines vs 200+ lines

---

## Out of scope

- Changing import behavior or validation rules
- Adding new import features
- Optimizing import performance (beyond preventing regression)
- Supporting non-CSV formats (Excel, JSON, etc.)

---

## Rollout plan

1. Create feature branch `refactor/consolidate-csv-importers`
2. Implement Steps 1-6 incrementally with tests
3. Code review with 2+ approvers
4. Run full test suite after each importer refactoring
5. Test in staging with sample CSV files
6. Merge to main after CI passes
7. Monitor production imports for 48 hours
8. Rollback if any import failures detected
