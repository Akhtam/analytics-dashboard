require 'rails_helper'

RSpec.describe "Calls dashboard", type: :request do
  it "renders the dashboard with the total, charts, and recent calls" do
    campaign = create(:campaign, name: "Alpha", source: "google_ads")
    create(:call, campaign: campaign, status: :converted, started_at: 1.hour.ago)
    create(:call, campaign: campaign, status: :missed, started_at: 2.hours.ago)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Call Analytics")
    expect(response.body).to include("Total calls")
    expect(response.body).to include("Alpha")
  end

  it "renders empty states when there are no calls" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No calls in this range.")
  end

  it "wraps the panels in a turbo-frame with an auto-submitting filter form" do
    get root_path

    expect(response.body).to include('turbo-frame id="dashboard"')
    expect(response.body).to include("auto-submit#submit")
    expect(response.body).not_to include(">Apply<")
  end

  it "shows the day-picker in hourly mode and hides it in daily mode" do
    get root_path, params: { granularity: "hourly" }
    expect(response.body).to include('name="day"')

    get root_path, params: { granularity: "daily" }
    expect(response.body).not_to include('name="day"')
  end

  it "renders the feed empty-row and does not mark initial rows as fresh" do
    create(:call, campaign: create(:campaign), started_at: 1.hour.ago)

    get root_path

    expect(response.body).to include('class="feed-empty"')
    expect(response.body).not_to include('class="fresh"')
  end

  describe "volume granularity and timeline" do
    let(:campaign) { create(:campaign) }

    around { |example| travel_to(Time.utc(2026, 6, 14, 12)) { example.run } }

    it "falls back to daily (7 bars) for an unknown granularity over 7 days" do
      create(:call, campaign: campaign, started_at: 1.hour.ago, status: :connected)

      get root_path, params: { granularity: "weekly" }

      expect(response).to have_http_status(:ok)
      expect(response.body.scan(/class="col"/).size).to eq(7)
    end

    it "renders 2 daily bars for the 24h range" do
      create(:call, campaign: campaign, started_at: 1.hour.ago, status: :connected)

      get root_path, params: { range: "24h", granularity: "daily" }

      expect(response.body.scan(/class="col"/).size).to eq(2)
    end

    it "renders 24 hourly bars" do
      create(:call, campaign: campaign, started_at: 1.hour.ago, status: :connected)

      get root_path, params: { granularity: "hourly" }

      expect(response.body.scan(/class="col"/).size).to eq(24)
    end

    it "falls back to today when the day param is invalid" do
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 14, 9), status: :connected)
      create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 11, 9), status: :connected)

      get root_path, params: { granularity: "hourly", range: "7d", day: "not-a-date" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('title="1 calls"') # only today's 9:00 call
    end
  end

  describe "POST /calls/simulate" do
    it "creates a call and returns no content" do
      create(:campaign)

      expect { post simulate_calls_path }.to change(Call, :count).by(1)
      expect(response).to have_http_status(:no_content)
    end
  end

  it "scopes the hourly volume chart to the selected day" do
    campaign = create(:campaign)
    create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 11, 9), status: :connected)
    create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 11, 9, 30), status: :connected)
    create(:call, campaign: campaign, started_at: Time.utc(2026, 6, 14, 10), status: :connected)

    travel_to Time.utc(2026, 6, 14, 12) do
      get root_path, params: { granularity: "hourly", day: "2026-06-11" }
    end

    # Only the selected day's two 9:00 calls are bucketed; the 06-14 call is excluded.
    expect(response.body).to include('title="2 calls"')
    expect(response.body).not_to include('title="1 calls"')
  end
end
