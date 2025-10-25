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
    end
  end
end
