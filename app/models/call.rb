class Call < ApplicationRecord
  belongs_to :campaign

  enum :status, { missed: 0, connected: 1, converted: 2 }

  validates :started_at, presence: true
  validates :status, presence: true

  scope :started_between, ->(range) { where(started_at: range) }
  scope :for_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  scope :with_status, ->(status) { where(status: status) }
  scope :on_day, ->(date) { where(started_at: date.in_time_zone.all_day) }
  scope :by_recency, -> { order(started_at: :desc) }

  # Prepend each new call into the live feed for every subscribed browser.
  after_create_commit lambda {
    broadcast_prepend_to "calls", target: "recent_calls", partial: "calls/call", locals: { call: self, fresh: true }
  }

  # Creates one realistic random call — the source for the live-feed simulator.
  def self.simulate!
    campaign = Campaign.random.first
    return unless campaign

    status = %i[missed connected connected converted].sample
    duration = status == :missed ? nil : rand(30..600)
    started_at = Time.current

    create!(
      campaign: campaign,
      status: status,
      started_at: started_at,
      ended_at: duration && started_at + duration,
      duration_seconds: duration,
      call_number: format("+1%010d", rand(2_000_000_000..9_999_999_999))
    )
  end
end
