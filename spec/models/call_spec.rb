require 'rails_helper'

RSpec.describe Call, type: :model do
  describe 'validations' do
    it 'is valid with campaign, started_at, and status' do
      expect(build(:call)).to be_valid
    end

    it 'is invalid without a campaign' do
      call = build(:call, campaign: nil)
      expect(call).not_to be_valid
      expect(call.errors[:campaign]).to include('must exist')
    end

    it 'is invalid without a started_at' do
      call = build(:call, started_at: nil)
      expect(call).not_to be_valid
      expect(call.errors[:started_at]).to include("can't be blank")
    end

    it 'is invalid without a status' do
      call = build(:call, status: nil)
      expect(call).not_to be_valid
      expect(call.errors[:status]).to include("can't be blank")
    end
  end

  describe 'status enum' do
    it 'defines the expected statuses' do
      expect(described_class.statuses).to eq('missed' => 0, 'connected' => 1, 'converted' => 2)
    end

    it 'exposes predicate methods' do
      expect(build(:call, status: :converted).converted?).to be(true)
      expect(build(:call, status: :converted).missed?).to be(false)
    end

    it 'raises when assigning an unknown status' do
      expect { build(:call, status: :unknown) }.to raise_error(ArgumentError)
    end
  end

  describe 'optional attributes' do
    it 'is valid without ended_at, call_number, and duration_seconds' do
      call = build(:call, ended_at: nil, call_number: nil, duration_seconds: nil)
      expect(call).to be_valid
    end

    it 'persists ended_at, call_number, and duration_seconds when provided' do
      ended = Time.current
      call = build(:call, ended_at: ended, call_number: '+15551234567', duration_seconds: 142)
      call.save!

      expect(call.reload).to have_attributes(
        call_number: '+15551234567',
        duration_seconds: 142
      )
      expect(call.ended_at).to be_within(1.second).of(ended)
    end
  end

  describe 'association' do
    it 'belongs to a campaign' do
      campaign = create(:campaign)
      call = build(:call, campaign: campaign)
      expect(call.campaign).to eq(campaign)
    end
  end

  describe 'scopes' do
    it '.started_between returns calls whose started_at falls in the range' do
      within = create(:call, started_at: 2.hours.ago)
      outside = create(:call, started_at: 2.days.ago)

      result = Call.started_between(1.day.ago..Time.current)

      expect(result).to include(within)
      expect(result).not_to include(outside)
    end

    it '.for_campaign limits to the given campaign' do
      mine = create(:call)
      other = create(:call)

      expect(Call.for_campaign(mine.campaign_id)).to contain_exactly(mine)
      expect(Call.for_campaign(mine.campaign_id)).not_to include(other)
    end

    it '.with_status limits to the given status' do
      converted = create(:call, status: :converted)
      missed = create(:call, status: :missed)

      expect(Call.with_status("converted")).to contain_exactly(converted)
      expect(Call.with_status("converted")).not_to include(missed)
    end

    it '.on_day returns calls started on the given local date' do
      on = create(:call, started_at: Time.utc(2026, 6, 11, 9))
      off = create(:call, started_at: Time.utc(2026, 6, 12, 9))

      result = Call.on_day(Date.new(2026, 6, 11))

      expect(result).to include(on)
      expect(result).not_to include(off)
    end

    it '.by_recency orders newest first' do
      older = create(:call, started_at: 2.hours.ago)
      newer = create(:call, started_at: 1.minute.ago)

      expect(Call.by_recency.to_a).to eq([newer, older])
    end
  end

  describe 'live feed broadcast' do
    it 'broadcasts a prepend to the calls stream when created' do
      expect { create(:call) }.to have_broadcasted_to("calls").from_channel(Turbo::StreamsChannel)
    end
  end

  describe '.simulate!' do
    it 'creates a random call for an existing campaign' do
      create(:campaign)
      expect { Call.simulate! }.to change(Call, :count).by(1)
    end

    it 'does nothing when there are no campaigns' do
      expect { Call.simulate! }.not_to change(Call, :count)
    end
  end
end
