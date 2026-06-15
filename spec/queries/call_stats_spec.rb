require 'rails_helper'

RSpec.describe CallStats do
  describe ".volume" do
    let(:campaign) { create(:campaign) }

    # Collapses the { [Time, status] => count } result into { [bucket, status] => count }
    # using the given block to normalize each Time, so assertions don't depend on
    # the exact Time/TimeWithZone class returned by the adapter.
    def bucketize(result)
      result.each_with_object(Hash.new(0)) do |((time, status), count), acc|
        acc[[ yield(time), status ]] += count
      end
    end

    it "groups calls by day and status" do
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 13, 12), status: :converted)
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 13, 13), status: :converted)
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 13, 14), status: :missed)
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 12, 9),  status: :connected)

      by_day = bucketize(CallStats.volume(Call.all, "day")) { |t| t.utc.to_date }

      expect(by_day[[ Date.new(2026, 6, 13), "converted" ]]).to eq(2)
      expect(by_day[[ Date.new(2026, 6, 13), "missed" ]]).to eq(1)
      expect(by_day[[ Date.new(2026, 6, 12), "connected" ]]).to eq(1)
    end

    it "groups calls by hour when granularity is hourly" do
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 13, 9, 15),  status: :converted)
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 13, 9, 45),  status: :connected)
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 13, 11, 0),  status: :missed)

      by_hour = bucketize(CallStats.volume(Call.all, "hour")) { |t| t.utc.strftime("%F %H") }

      expect(by_hour[[ "2026-06-13 09", "converted" ]]).to eq(1)
      expect(by_hour[[ "2026-06-13 09", "connected" ]]).to eq(1)
      expect(by_hour[[ "2026-06-13 11", "missed" ]]).to eq(1)
    end
  end

  describe ".conversion_by_campaign" do
    it "returns per-campaign totals and converted counts" do
      alpha = create(:campaign, name: "Alpha", source: "google_ads")
      beta  = create(:campaign, name: "Beta", source: "facebook")
      create(:campaign, name: "Gamma") # no calls

      create(:call, campaign: alpha, status: :converted)
      create(:call, campaign: alpha, status: :connected)
      create(:call, campaign: beta,  status: :missed)

      rows = CallStats.conversion_by_campaign(Call.all).to_a
      by_name = rows.index_by(&:name)

      expect(by_name.keys).to match_array(%w[Alpha Beta])
      expect(by_name["Alpha"]).to have_attributes(source: "google_ads")
      expect(by_name["Alpha"].total.to_i).to eq(2)
      expect(by_name["Alpha"].converted.to_i).to eq(1)
      expect(by_name["Beta"].total.to_i).to eq(1)
      expect(by_name["Beta"].converted.to_i).to eq(0)
    end

    it "excludes campaigns with no calls" do
      active = create(:campaign, name: "Active")
      create(:campaign, name: "Empty")
      create(:call, campaign: active, status: :connected)

      names = CallStats.conversion_by_campaign(Call.all).to_a.map(&:name)

      expect(names).to eq([ "Active" ])
    end
  end
end
