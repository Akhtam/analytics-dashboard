FactoryBot.define do
  factory :campaign do
    sequence(:name) { |n| "Campaign #{n}" }
    sequence(:tracking_number) { |n| format("+1415555%04d", n) }
    source { "google_ads" }
  end
end
