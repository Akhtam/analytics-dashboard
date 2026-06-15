class CallStats
  # Canonical granularity vocabulary. The UI/params use the keys ("daily"/
  # "hourly"); UNITS maps each to the SQL date_trunc unit.
  DAILY = "daily"
  HOURLY = "hourly"
  GRANULARITIES = [ DAILY, HOURLY ].freeze
  DEFAULT_GRANULARITY = DAILY
  UNITS = { DAILY => "day", HOURLY => "hour" }.freeze

  # `unit` is a SQL date_trunc unit ("day"/"hour") — see CallStats::UNITS.
  def self.volume(scope, unit)
    scope.group(Arel.sql("date_trunc('#{unit}', started_at)"))
         .group(:status)
         .count   # => { [Time, "converted"] => 12, ... }, reshape for the chart
  end

  def self.conversion_by_campaign(scope)
    scope.joins(:campaign)
         .group("campaigns.id", "campaigns.name", "campaigns.source")
         .select(<<~SQL)
           campaigns.id, campaigns.name, campaigns.source,
           COUNT(*) AS total,
           COUNT(*) FILTER (WHERE status = #{Call.statuses["converted"]}) AS converted
         SQL
  end
end
