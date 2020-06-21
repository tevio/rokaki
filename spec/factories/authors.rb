FactoryBot.define do
  factory :author do
    sequence(:first_name) { |n| "First#{n}Name" }
    sequence(:last_name) { |n| "Last#{n}Name" }
  end
end

