FactoryBot.define do
  factory :call do
    association :campaign
    started_at { Time.current }
    status { :connected }
    sequence(:call_number) { |n| format("+1415555%04d", n) }

    trait :missed do
      status { :missed }
      ended_at { nil }
      duration_seconds { nil }
    end

    trait :connected do
      status { :connected }
      duration_seconds { 120 }
      ended_at { started_at + 120.seconds }
    end

    trait :converted do
      status { :converted }
      duration_seconds { 240 }
      ended_at { started_at + 240.seconds }
    end
  end
end
