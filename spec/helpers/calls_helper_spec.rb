require 'rails_helper'

RSpec.describe CallsHelper, type: :helper do
  describe "#volume_buckets" do
    it "zero-fills the timeline and sums totals, matching keys by epoch" do
      t0 = Time.utc(2026, 6, 13)
      t1 = Time.utc(2026, 6, 14)
      empty = Time.utc(2026, 6, 15)

      # Volume keyed by plain Time (as the DB returns); timeline uses TimeWithZone
      # to exercise the epoch-based key matching.
      volume = {
        [ t0, "converted" ] => 2,
        [ t0, "connected" ] => 1,
        [ t1, "missed" ] => 3
      }
      timeline = [ t0.in_time_zone, t1.in_time_zone, empty.in_time_zone ]

      result = helper.volume_buckets(volume, timeline)

      expect(result.size).to eq(3)
      expect(result[0]).to include(time: t0.in_time_zone, converted: 2, connected: 1, missed: 0, total: 3)
      expect(result[1]).to include(converted: 0, connected: 0, missed: 3, total: 3)
      expect(result[2]).to include(converted: 0, connected: 0, missed: 0, total: 0)
    end
  end

  describe "#conversion_rows" do
    let(:row_class) { Struct.new(:name, :source, :total, :converted) }

    it "casts string counts, computes the rate, and sorts by rate descending" do
      alpha = row_class.new("Alpha", "google_ads", "4", "1") # 25%
      beta  = row_class.new("Beta", "facebook", "2", "2")    # 100%

      result = helper.conversion_rows([ alpha, beta ])

      expect(result.map { |r| r[:name] }).to eq(%w[Beta Alpha])
      expect(result.first).to include(name: "Beta", source: "facebook", total: 2, converted: 2, rate: 100)
      expect(result.last).to include(total: 4, converted: 1, rate: 25)
    end

    it "returns a rate of 0 when total is zero" do
      result = helper.conversion_rows([ row_class.new("X", "s", "0", "0") ])

      expect(result.first[:rate]).to eq(0)
    end
  end

  describe "#volume_axis_label" do
    it "returns the weekday for daily granularity" do
      time = Time.utc(2026, 6, 14, 5)
      expect(helper.volume_axis_label(time, "daily")).to eq(time.strftime("%a"))
    end

    it "labels every third hour in hourly granularity" do
      expect(helper.volume_axis_label(Time.utc(2026, 6, 14, 0), "hourly")).to eq("12am")
      expect(helper.volume_axis_label(Time.utc(2026, 6, 14, 3), "hourly")).to eq("3am")
      expect(helper.volume_axis_label(Time.utc(2026, 6, 14, 15), "hourly")).to eq("3pm")
    end

    it "returns blank for non-labeled hours" do
      expect(helper.volume_axis_label(Time.utc(2026, 6, 14, 1), "hourly")).to eq("")
      expect(helper.volume_axis_label(Time.utc(2026, 6, 14, 14), "hourly")).to eq("")
    end
  end

  describe "#relative_time" do
    around { |example| travel_to(Time.utc(2026, 6, 14, 12)) { example.run } }

    it "returns 'just now' under a minute" do
      expect(helper.relative_time(30.seconds.ago)).to eq("just now")
    end

    it "returns minutes ago under an hour" do
      expect(helper.relative_time(5.minutes.ago)).to eq("5m ago")
    end

    it "returns hours ago under a day" do
      expect(helper.relative_time(3.hours.ago)).to eq("3h ago")
    end

    it "returns a formatted date beyond a day" do
      time = 2.days.ago
      expect(helper.relative_time(time)).to eq(time.strftime("%b %-d, %H:%M"))
    end

    it "returns blank for nil" do
      expect(helper.relative_time(nil)).to eq("")
    end
  end

  describe "#format_duration" do
    it "formats seconds as m:ss" do
      expect(helper.format_duration(142)).to eq("2:22")
      expect(helper.format_duration(65)).to eq("1:05")
    end

    it "returns an em dash for nil or zero" do
      expect(helper.format_duration(nil)).to eq("—")
      expect(helper.format_duration(0)).to eq("—")
    end
  end
end
