require 'rails_helper'

RSpec.describe Campaign, type: :model do
  describe 'scopes' do
    it '.alphabetical orders by name' do
      b = create(:campaign, name: "Beta")
      a = create(:campaign, name: "Alpha")

      expect(Campaign.alphabetical.to_a).to eq([a, b])
    end

    it '.random returns all campaigns' do
      a = create(:campaign)
      b = create(:campaign)

      expect(Campaign.random).to contain_exactly(a, b)
    end
  end

  describe 'validations' do
    it 'is valid with source, name, and tracking_number' do
      expect(build(:campaign)).to be_valid
    end

    describe 'source' do
      it 'is invalid without a source' do
        campaign = build(:campaign, source: nil)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:source]).to include("can't be blank")
      end
    end

    describe 'name' do
      it 'is invalid without a name' do
        campaign = build(:campaign, name: nil)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:name]).to include("can't be blank")
      end

      it 'is invalid with a duplicate name' do
        create(:campaign, name: 'Black Friday')
        duplicate = build(:campaign, name: 'Black Friday')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'is invalid with a name that differs only in case (case-insensitive)' do
        create(:campaign, name: 'Black Friday')
        duplicate = build(:campaign, name: 'black friday')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end
    end

    describe 'tracking_number' do
      it 'is invalid without a tracking_number' do
        campaign = build(:campaign, tracking_number: nil)
        expect(campaign).not_to be_valid
        expect(campaign.errors[:tracking_number]).to include("can't be blank")
      end

      it 'is invalid with a duplicate tracking_number' do
        create(:campaign, tracking_number: 'TRK-200')
        duplicate = build(:campaign, tracking_number: 'TRK-200')

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:tracking_number]).to include('has already been taken')
      end
    end
  end
end
