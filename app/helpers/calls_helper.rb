module CallsHelper
  # Reshapes CallStats.volume ({ [Time, status] => count }) into one bucket per
  # entry in `timeline` (so empty periods are zero-filled), ascending by time:
  #   [{ time:, converted:, connected:, missed:, total: }, ...]
  # Keys are compared by epoch seconds so the DB's Time and the generated
  # TimeWithZone match regardless of class.
  def volume_buckets(volume, timeline)
    counts = Hash.new(0)
    volume.each { |(time, status), count| counts[[ time.to_i, status ]] = count }

    timeline.map do |time|
      converted = counts[[ time.to_i, "converted" ]]
      connected = counts[[ time.to_i, "connected" ]]
      missed    = counts[[ time.to_i, "missed" ]]

      { time: time, converted: converted, connected: connected, missed: missed,
        total: converted + connected + missed }
    end
  end

  # Sorts the conversion-by-campaign rows by rate descending, casting the SQL
  # string counts to integers and computing the percentage.
  def conversion_rows(by_campaign)
    by_campaign.map do |row|
      total = row.total.to_i
      converted = row.converted.to_i

      {
        name: row.name,
        source: row.source,
        total: total,
        converted: converted,
        rate: total.zero? ? 0 : (converted * 100.0 / total).round
      }
    end.sort_by { |row| -row[:rate] }
  end

  # X-axis label for a volume bucket: weekday for daily; for hourly, label only
  # every third hour to avoid crowding the 24 bars.
  def volume_axis_label(time, granularity)
    return time.strftime("%a") unless granularity == CallStats::HOURLY
    return "" unless (time.hour % 3).zero?

    time.strftime("%-l%P")
  end

  # Relative "time ago" for the recent-calls feed.
  def relative_time(time)
    return "" if time.blank?

    seconds = (Time.current - time).to_i
    case seconds
    when (..59)      then "just now"
    when (60..3599)  then "#{seconds / 60}m ago"
    when (3600..86_399) then "#{seconds / 3600}h ago"
    else time.strftime("%b %-d, %H:%M")
    end
  end

  # Call duration as m:ss (em dash when absent, e.g. missed calls).
  def format_duration(seconds)
    return "—" if seconds.blank? || seconds.zero?

    minutes, secs = seconds.divmod(60)
    format("%d:%02d", minutes, secs)
  end
end
