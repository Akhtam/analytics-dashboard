# Builds a filtered Call relation from the dashboard's filter params
# (range / campaign / outcome). Every dashboard panel is built from the relation
# this returns, so the filters apply uniformly.
class CallsFilter
  # Each range maps to a lambda returning the time window matched against
  # started_at. Lambdas (rather than precomputed ranges) keep the window
  # relative to "now" every time the filter runs.
  LAST_24H = "24h"
  LAST_7D = "7d"

  RANGES = {
    LAST_24H => -> { 24.hours.ago..Time.zone.now },
    LAST_7D  => -> { 7.days.ago..Time.zone.now }
  }.freeze

  DEFAULT_RANGE = LAST_7D
  ALL = "all"

  def initialize(filter_params = {})
    @filter_params = filter_params || {}
  end

  # The filtered ActiveRecord::Relation feeding every dashboard panel.
  def relation
    scope = Call.started_between(range_window)
    scope = scope.for_campaign(campaign) if campaign_selected?
    scope = scope.with_status(outcome) if outcome_selected?
    scope
  end

  # The selected range key, normalized to a known value (for the filter UI and
  # dashboard's day/timeline decisions).
  def range
    RANGES.key?(@filter_params[:range]) ? @filter_params[:range] : DEFAULT_RANGE
  end

  private

  def range_window
    RANGES.fetch(range).call
  end

  def campaign
    @filter_params[:campaign]
  end

  def outcome
    @filter_params[:outcome]
  end

  def campaign_selected?
    campaign.present? && campaign != ALL
  end

  def outcome_selected?
    outcome.present? && outcome != ALL && Call.statuses.key?(outcome)
  end
end
