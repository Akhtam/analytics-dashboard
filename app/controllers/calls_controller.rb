class CallsController < ApplicationController
  helper_method :range, :granularity

  def index
    calls = calls_filter.relation

    @total = calls.count
    @volume = CallStats.volume(volume_scope(calls), CallStats::UNITS.fetch(granularity))
    @volume_timeline = volume_timeline
    @by_campaign = CallStats.conversion_by_campaign(calls)
    @recent = calls.includes(:campaign).by_recency.limit(12)
    @campaigns = Campaign.alphabetical
  end

  # Creates one random call (web-process simulator for the live feed); the
  # broadcast from Call#after_create_commit updates every subscribed browser.
  def simulate
    Call.simulate!
    head :no_content
  end

  private

  def filter_params
    @filter_params ||= params.permit(:range, :campaign, :outcome, :granularity, :day)
  end

  def calls_filter
    @calls_filter ||= CallsFilter.new(filter_params)
  end

  # Selected range / granularity, normalized and memoized. Exposed to the view
  # via helper_method; the other helpers below read them through these methods,
  # so there's no dependency on assignment order in #index.
  def range
    @range ||= calls_filter.range
  end

  def granularity
    @granularity ||=
      if CallStats::GRANULARITIES.include?(filter_params[:granularity])
        filter_params[:granularity]
      else
        CallStats::DEFAULT_GRANULARITY
      end
  end

  # Hourly drills into a single day (the day-picker); daily uses the full range.
  def volume_scope(calls)
    return calls unless granularity == CallStats::HOURLY

    calls.on_day(selected_day)
  end

  # The day-picker only applies to the 7-day range; otherwise the hourly chart
  # uses today (and any leftover `day` param is ignored).
  def selected_day
    @selected_day ||= parse_day
  end

  def parse_day
    return Time.zone.today unless range == CallsFilter::LAST_7D

    Date.parse(filter_params[:day].to_s)
  rescue ArgumentError, TypeError
    Time.zone.today
  end

  # The complete set of bucket start-times the volume chart should show, so the
  # view can zero-fill empty periods. Matches CallStats' date_trunc buckets.
  def volume_timeline
    if granularity == CallStats::HOURLY
      day_start = selected_day.in_time_zone.beginning_of_day
      (0..23).map { |hour| day_start + hour.hours }
    else
      days = range == CallsFilter::LAST_24H ? 2 : 7
      start = Time.current.beginning_of_day - (days - 1).days
      (0...days).map { |offset| start + offset.days }
    end
  end
end
