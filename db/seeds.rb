# Guard: the generator wipes ALL campaigns and calls before regenerating, so it
# must never run against production (or any non-development) data.
unless Rails.env.development?
  return
end

# Seeds the database with realistic mock Campaign + Call data for the analytics
# dashboard. This is development-only demo data: running it WIPES all existing
# campaigns and calls before regenerating, so it is guarded to development below.
# Load it with: bin/rails db:seed

# Generates realistic mock Campaign + Call data for the analytics dashboard.
#
# Idempotent: clears existing calls and campaigns before regenerating, so it is
# safe to re-run in development.
class MockDataGenerator
  # Each campaign belongs to a source. Per-source profiles give the
  # "conversion rate by campaign source" panel meaningful variation.
  CAMPAIGNS = [
    { source: "google_ads",     name: "Summer Sale 2026" },
    { source: "google_ads",     name: "Brand Keywords" },
    { source: "facebook",       name: "Retargeting Q2" },
    { source: "instagram",      name: "Influencer Launch" },
    { source: "organic_search", name: "SEO Landing Pages" },
    { source: "referral",       name: "Partner Network" },
    { source: "direct",         name: "Direct Dials" }
  ].freeze

  # Probability of each terminal status by source: { missed:, converted: }.
  # The remainder is "connected" (answered but not converted).
  SOURCE_PROFILES = {
    "google_ads"     => { missed: 0.15, converted: 0.28 },
    "facebook"       => { missed: 0.25, converted: 0.15 },
    "instagram"      => { missed: 0.30, converted: 0.12 },
    "organic_search" => { missed: 0.10, converted: 0.35 },
    "referral"       => { missed: 0.12, converted: 0.40 },
    "direct"         => { missed: 0.20, converted: 0.30 }
  }.freeze
  DEFAULT_PROFILE = { missed: 0.25, converted: 0.20 }.freeze

  # Relative call volume per hour (index = hour 0-23), weighted to business hours.
  HOUR_WEIGHTS = [
    1, 1, 1, 1, 1, 2,      # 00-05
    3, 5, 8, 10, 12, 12,   # 06-11
    10, 11, 12, 11, 9, 7,  # 12-17
    5, 4, 3, 2, 2, 1       # 18-23
  ].freeze

  def initialize(days: 7, calls_per_day: 80, now: Time.current)
    @days = days
    @calls_per_day = calls_per_day
    @now = now
  end

  def generate!
    ActiveRecord::Base.transaction do
      reset!
      campaigns = create_campaigns
      create_calls(campaigns)
    end

    { campaigns: Campaign.count, calls: Call.count }
  end

  private

  def reset!
    Call.delete_all
    Campaign.delete_all
  end

  def create_campaigns
    CAMPAIGNS.each_with_index.map do |attrs, i|
      Campaign.create!(
        source: attrs[:source],
        name: attrs[:name],
        tracking_number: format("+1415555%04d", 1000 + i)
      )
    end
  end

  def create_calls(campaigns)
    rows = []

    @days.times do |day_offset|
      day = (@now - day_offset.days).beginning_of_day

      @calls_per_day.times do
        started_at = day + weighted_hour.hours + rand(0..59).minutes + rand(0..59).seconds
        next if started_at > @now # never generate calls in the future

        rows << build_call_row(campaigns.sample, started_at)
      end
    end

    Call.insert_all(rows) if rows.any?
  end

  def build_call_row(campaign, started_at)
    status = weighted_status(campaign.source)
    ended_at, duration = timing_for(status, started_at)

    {
      campaign_id: campaign.id,
      started_at: started_at,
      status: Call.statuses.fetch(status.to_s),
      ended_at: ended_at,
      duration_seconds: duration,
      call_number: random_phone_number,
      created_at: started_at,
      updated_at: started_at
    }
  end

  def weighted_status(source)
    profile = SOURCE_PROFILES.fetch(source, DEFAULT_PROFILE)
    roll = rand

    return :missed    if roll < profile[:missed]
    return :converted if roll < profile[:missed] + profile[:converted]

    :connected
  end

  # Missed calls have no answer, so no end time or duration.
  def timing_for(status, started_at)
    return [ nil, nil ] if status == :missed

    duration = rand(30..900) # 30s to 15min
    ended_at = started_at + duration

    # A completed call can't end in the future; clamp to now and shorten the
    # recorded duration to match so the two stay consistent.
    if ended_at > @now
      ended_at = @now
      duration = (ended_at - started_at).to_i
    end

    [ ended_at, duration ]
  end

  def weighted_hour
    target = rand(HOUR_WEIGHTS.sum)
    cumulative = 0

    HOUR_WEIGHTS.each_with_index do |weight, hour|
      cumulative += weight
      return hour if target < cumulative
    end

    23
  end

  def random_phone_number
    format("+1%010d", rand(2_000_000_000..9_999_999_999))
  end
end

result = MockDataGenerator.new.generate!

puts "Seeded #{result[:campaigns]} campaigns and #{result[:calls]} calls."
