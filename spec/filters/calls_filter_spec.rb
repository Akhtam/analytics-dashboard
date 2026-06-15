require 'rails_helper'

RSpec.describe CallsFilter do
  let(:campaign) { create(:campaign) }
  let(:other_campaign) { create(:campaign) }

  # Freeze "now" so the relative range windows are deterministic.
  around do |example|
    travel_to(Time.zone.parse("2026-06-13 12:00:00")) { example.run }
  end

  def create_call(started_at:, campaign: nil, status: :connected)
    campaign ||= self.campaign
    create(:call, campaign: campaign, started_at: started_at, status: status)
  end

  def results(params = {})
    described_class.new(params).relation
  end

  describe "date range" do
    it "defaults to the last 7 days when no range is given" do
      within = create_call(started_at: 3.days.ago)
      outside = create_call(started_at: 8.days.ago)

      expect(results).to include(within)
      expect(results).not_to include(outside)
    end

    it "falls back to the last 7 days for an unknown range" do
      within = create_call(started_at: 3.days.ago)
      outside = create_call(started_at: 8.days.ago)

      expect(results(range: "bogus")).to include(within)
      expect(results(range: "bogus")).not_to include(outside)
    end

    it "limits to the last 24 hours for '24h'" do
      within = create_call(started_at: 2.hours.ago)
      outside = create_call(started_at: 26.hours.ago)

      expect(results(range: "24h")).to include(within)
      expect(results(range: "24h")).not_to include(outside)
    end
  end

  describe "campaign filter" do
    it "filters to the given campaign" do
      mine = create_call(started_at: 1.hour.ago, campaign: campaign)
      theirs = create_call(started_at: 1.hour.ago, campaign: other_campaign)

      expect(results(campaign: campaign.id)).to include(mine)
      expect(results(campaign: campaign.id)).not_to include(theirs)
    end

    it "does not filter when campaign is 'all'" do
      mine = create_call(started_at: 1.hour.ago, campaign: campaign)
      theirs = create_call(started_at: 1.hour.ago, campaign: other_campaign)

      expect(results(campaign: "all")).to include(mine, theirs)
    end

    it "does not filter when campaign is blank" do
      mine = create_call(started_at: 1.hour.ago, campaign: campaign)
      theirs = create_call(started_at: 1.hour.ago, campaign: other_campaign)

      expect(results(campaign: "")).to include(mine, theirs)
    end
  end

  describe "outcome filter" do
    it "filters to the given status" do
      converted = create_call(started_at: 1.hour.ago, status: :converted)
      missed = create_call(started_at: 1.hour.ago, status: :missed)

      expect(results(outcome: "converted")).to include(converted)
      expect(results(outcome: "converted")).not_to include(missed)
    end

    it "does not filter when outcome is 'all'" do
      converted = create_call(started_at: 1.hour.ago, status: :converted)
      missed = create_call(started_at: 1.hour.ago, status: :missed)

      expect(results(outcome: "all")).to include(converted, missed)
    end

    it "ignores an unknown outcome value" do
      converted = create_call(started_at: 1.hour.ago, status: :converted)
      missed = create_call(started_at: 1.hour.ago, status: :missed)

      expect(results(outcome: "nonsense")).to include(converted, missed)
    end
  end

  describe "combined filters" do
    it "applies range, campaign and outcome together" do
      match = create_call(started_at: 1.hour.ago, campaign: campaign, status: :converted)
      wrong_campaign = create_call(started_at: 1.hour.ago, campaign: other_campaign, status: :converted)
      wrong_status = create_call(started_at: 1.hour.ago, campaign: campaign, status: :missed)
      too_old = create_call(started_at: 10.days.ago, campaign: campaign, status: :converted)

      result = results(range: "7d", campaign: campaign.id, outcome: "converted")

      expect(result).to include(match)
      expect(result).not_to include(wrong_campaign, wrong_status, too_old)
    end
  end

  describe "#range" do
    it "returns the selected range key" do
      expect(described_class.new(range: "24h").range).to eq("24h")
    end

    it "defaults to 7d when no range is given" do
      expect(described_class.new({}).range).to eq("7d")
    end

    it "falls back to 7d for an unknown range" do
      expect(described_class.new(range: "bogus").range).to eq("7d")
    end
  end
end
