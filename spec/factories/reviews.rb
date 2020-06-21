FactoryBot.define do
  factory :review do
    sequence(:title) { |n| "Review #{n} Title" }
    article
  end
end

