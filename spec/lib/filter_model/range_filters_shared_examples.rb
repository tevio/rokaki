# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples "FilterModel::RangeFilters" do |selected_db|
  describe 'range-style filters on top-level columns' do
    let(:a1_published) { Time.utc(2024, 1, 1, 12, 0, 0) }
    let(:a2_published) { Time.utc(2024, 6, 1, 12, 0, 0) }
    let(:a3_published) { Time.utc(2024, 12, 31, 12, 0, 0) }

    let!(:author) { Author.create!(first_name: 'Ada', last_name: 'Lovelace') }
    let!(:article_1) { Article.create!(title: 'A1', content: 'c1', published: a1_published, author: author) }
    let!(:article_2) { Article.create!(title: 'A2', content: 'c2', published: a2_published, author: author) }
    let!(:article_3) { Article.create!(title: 'A3', content: 'c3', published: a3_published, author: author) }

    let(:klass) do
      Class.new do
        include Rokaki::FilterModel
        filter_key_prefix :__
        filter_model :article, db: selected_db
        # enable top-level field key
        filters :published

        attr_accessor :filters
        def initialize(filters: {})
          @filters = filters
        end
      end
    end

    it 'supports between via Range' do
      results = klass.new(filters: { published: (Time.utc(2024, 1, 1)..Time.utc(2024, 12, 1)) }).results
      expect(results).to include(article_1, article_2)
      expect(results).not_to include(article_3)
    end

    it 'treats Array as equality list (IN) on the field' do
      results = klass.new(filters: { published: [a1_published, a2_published] }).results
      expect(results).to include(article_1, article_2)
      expect(results).not_to include(article_3)
    end

    it 'supports between via Hash { from:, to: }' do
      results = klass.new(filters: { published: { between: { from: Time.utc(2024, 1, 1), to: Time.utc(2024, 6, 15) } } }).results
      expect(results).to include(article_1, article_2)
      expect(results).not_to include(article_3)
    end

    it 'accepts alias keys since/until' do
      results = klass.new(filters: { published: { since: Time.utc(2024, 1, 1), until: Time.utc(2024, 6, 1) } }).results
      expect(results).to include(article_1, article_2)
      expect(results).not_to include(article_3)
    end

    it 'treats min as lower bound (>=)' do
      results = klass.new(filters: { published: { min: Time.utc(2024, 6, 1) } }).results
      expect(results).to include(article_2, article_3)
      expect(results).not_to include(article_1)
    end

    it 'treats max as upper bound (<=)' do
      results = klass.new(filters: { published: { max: Time.utc(2024, 6, 1) } }).results
      expect(results).to include(article_1, article_2)
      expect(results).not_to include(article_3)
    end
  end
end

RSpec.shared_examples "FilterModel::NestedRangeFilters" do |selected_db|
  describe 'range-style filters on nested columns' do
    let(:r1_time) { Time.utc(2024, 1, 10, 10, 0, 0) }
    let(:r2_time) { Time.utc(2024, 6, 10, 10, 0, 0) }
    let(:r3_time) { Time.utc(2024, 12, 10, 10, 0, 0) }

    let!(:author) { Author.create!(first_name: 'Grace', last_name: 'Hopper') }
    let!(:article_1) { Article.create!(title: 'A1', content: 'c1', published: Time.utc(2024,1,1), author: author) }
    let!(:article_2) { Article.create!(title: 'A2', content: 'c2', published: Time.utc(2024,6,1), author: author) }

    let!(:review_1) { Review.create!(title: 'R1', content: 'x', published: r1_time, article: article_1) }
    let!(:review_2) { Review.create!(title: 'R2', content: 'y', published: r2_time, article: article_1) }
    let!(:review_3) { Review.create!(title: 'R3', content: 'z', published: r3_time, article: article_2) }

    let(:klass) do
      Class.new do
        include Rokaki::FilterModel
        filter_key_prefix :__
        filter_model :article, db: selected_db
        # enable nested reviews.published key
        filters reviews: :published

        attr_accessor :filters
        def initialize(filters: {})
          @filters = filters
        end
      end
    end

    it 'supports nested between via Range on reviews.published' do
      results = klass.new(filters: { reviews: { published: (Time.utc(2024, 1, 1)..Time.utc(2024, 6, 30)) } }).results
      # Only article_1 has at least one review within the range; article_2's review is outside
      expect(results).to include(article_1)
      expect(results).not_to include(article_2)
    end

    it 'supports nested lower bound via from' do
      results = klass.new(filters: { reviews: { published: { from: Time.utc(2024, 6, 1) } } }).results
      expect(results).to include(article_1, article_2)
    end

    it 'supports nested upper bound via max' do
      results = klass.new(filters: { reviews: { published: { max: Time.utc(2024, 6, 15) } } }).results
      expect(results).to include(article_1)
      expect(results).not_to include(article_2)
    end
  end
end
