# frozen_string_literal: true

class FinancialSnapshot < ApplicationRecord
  belongs_to :user

  enum :status, {
    pending: 0,
    complete: 1,
    error: 2,
    stale: 3,
    empty: 4,
    rolled_back: 5
  }, default: :pending

  validates :snapshot_at, presence: true
  validates :schema_version, presence: true, inclusion: { in: 1..2 }

  before_validation :normalize_snapshot_at

  scope :for_user, ->(user) { where(user: user) }
  scope :complete_only, -> { where(status: :complete) }

  def self.latest_for_user(user)
    # A snapshot can be marked `stale` when it's older than desired, but it is still
    # a valid persisted snapshot (and should remain exportable).
    for_user(user).where(status: [ :complete, :stale ]).order(snapshot_at: :desc).first
  end

  def self.for_date_range(user, start_date, end_date)
    tz = ActiveSupport::TimeZone[APP_TIMEZONE]
    start_time = tz.parse(start_date.to_date.to_s).beginning_of_day
    end_time = tz.parse(end_date.to_date.to_s).end_of_day
    for_user(user).where(snapshot_at: start_time..end_time).order(snapshot_at: :asc)
  end

  def self.recent_for_user(user, days = 30)
    tz = ActiveSupport::TimeZone[APP_TIMEZONE]
    cutoff = tz.now.beginning_of_day - days.to_i.days
    for_user(user).where("snapshot_at >= ?", cutoff).order(snapshot_at: :desc)
  end

  def warnings
    Array(data&.dig("data_quality", "warnings"))
  end

  def data_quality_score
    Reporting::DataQualityValidator.new(self).score
  end

  def self.rollback_to_date(user, date)
    tz = ActiveSupport::TimeZone[APP_TIMEZONE]
    cutoff = tz.parse(date.to_date.to_s).end_of_day
    for_user(user).where("snapshot_at > ?", cutoff).update_all(status: statuses[:rolled_back], updated_at: Time.current)
  end

  private

  def normalize_snapshot_at
    return if snapshot_at.blank?

    tz = ActiveSupport::TimeZone[APP_TIMEZONE]

    time =
      case snapshot_at
      when Date
        tz.parse(snapshot_at.to_s)
      else
        snapshot_at.in_time_zone(tz)
      end

    self.snapshot_at = time.beginning_of_day
  end
end
