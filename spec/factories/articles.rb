FactoryBot.define do
  factory :article do
    sequence(:title) { |n| "Article #{n} Title" }
    sequence(:content) { |n| "Article #{n} Content" }
    published { DateTime.now }
    author
  end
end
