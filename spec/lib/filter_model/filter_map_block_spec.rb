# frozen_string_literal: true
require 'spec_helper'

module Rokaki
  RSpec.shared_examples "FilterModel::FilterMapBlockDSL" do |selected_db|
    describe "filter_map block DSL" do
      let!(:author) { Author.create!(first_name: 'Ada', last_name: 'Lovelace') }
      let!(:article_1) { Article.create!(title: 'The First Article', content: 'Alpha', published: DateTime.now, author: author) }
      let!(:article_2) { Article.create!(title: 'Second', content: 'Beta', published: DateTime.now, author: author) }

      let(:klass_title_only) do
        Class.new do
          include Rokaki::FilterModel

          filter_key_prefix :__
          filter_model :article, db: selected_db
          define_query_key :q

          filter_map do
            like title: :circumfix
          end

          attr_accessor :filters
          def initialize(filters: {})
            @filters = filters
          end
        end
      end

      let(:klass_nested_only) do
        Class.new do
          include Rokaki::FilterModel

          filter_key_prefix :__
          filter_model :article, db: selected_db
          define_query_key :q

          filter_map do
            nested :author do
              like first_name: :prefix
            end
          end

          attr_accessor :filters
          def initialize(filters: {})
            @filters = filters
          end
        end
      end

      it "filters with circumfix on a model column using the query key" do
        results = klass_title_only.new(filters: { q: 'First' }).results
        expect(results).to include(article_1)
        expect(results).not_to include(article_2)
      end

      it "filters nested association columns using the same query key" do
        results = klass_nested_only.new(filters: { q: 'Ada' }).results
        expect(results).to include(article_1, article_2)
      end

      context "range filters in block DSL" do
        let!(:a3_time) { Time.utc(2024, 12, 31, 12, 0, 0) }
        let!(:a1_time) { Time.utc(2024, 1, 1, 12, 0, 0) }
        let!(:a2_time) { Time.utc(2024, 6, 1, 12, 0, 0) }

        let!(:author_r) { Author.create!(first_name: 'Grace', last_name: 'Hopper') }
        let!(:ar1) { Article.create!(title: 'A1', content: 'c1', published: a1_time, author: author_r) }
        let!(:ar2) { Article.create!(title: 'A2', content: 'c2', published: a2_time, author: author_r) }
        let!(:ar3) { Article.create!(title: 'A3', content: 'c3', published: a3_time, author: author_r) }

        let(:klass_with_top_level_range) do
          Class.new do
            include Rokaki::FilterModel

            filter_key_prefix :__
            filter_model :article, db: selected_db
            define_query_key :q

            filter_map do
              # Enable top-level field; range behavior is value-driven via q
              filters :published
            end

            attr_accessor :filters
            def initialize(filters: {})
              @filters = filters
            end
          end
        end

        let(:klass_with_nested_range) do
          Class.new do
            include Rokaki::FilterModel

            filter_key_prefix :__
            filter_model :article, db: selected_db
            define_query_key :q

            filter_map do
              nested :reviews do
                filters :published
              end
            end

            attr_accessor :filters
            def initialize(filters: {})
              @filters = filters
            end
          end
        end

        it "supports top-level between via Range" do
          res = klass_with_top_level_range.new(filters: { q: (Time.utc(2024,1,1)..Time.utc(2024,12,1)) }).results
          expect(res).to include(ar1, ar2)
          expect(res).not_to include(ar3)
        end

        it "supports nested lower/upper bounds via sub-keys on reviews.published" do
          r1 = Review.create!(title: 'R1', content: 'x', published: Time.utc(2024, 1, 10), article: ar1)
          r2 = Review.create!(title: 'R2', content: 'y', published: Time.utc(2024, 6, 10), article: ar1)
          r3 = Review.create!(title: 'R3', content: 'z', published: Time.utc(2025, 1, 10), article: ar3)

          res = klass_with_nested_range.new(filters: { q: { from: Time.utc(2024,1,1), to: Time.utc(2024,12,31) } }).results
          expect(res).to include(ar1)
          expect(res).not_to include(ar3)
        end
      end
    end
  end
end
