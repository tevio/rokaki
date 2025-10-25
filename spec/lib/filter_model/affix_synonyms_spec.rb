# frozen_string_literal: true

module Rokaki
  module FilterModel
    RSpec.shared_examples "FilterModel::AffixSynonyms" do |selected_db|
      describe "affix synonyms for circumfix" do
        let!(:author) { Author.create!(first_name: 'Ada', last_name: 'Lovelace') }
        let!(:article_1) { Article.create!(title: 'The First Article', content: 'Alpha', published: DateTime.now, author: author) }
        let!(:article_2) { Article.create!(title: 'Second', content: 'Beta', published: DateTime.now, author: author) }

        def build_klass(mode_sym, db)
          Class.new do
            include Rokaki::FilterModel

            filter_key_prefix :__
            filter_model :article, db: db

            define_query_key :q
            like title: mode_sym

            attr_accessor :filters
            def initialize(filters: {})
              @filters = filters
            end
          end
        end

        it "treats :parafix as :circumfix" do
          klass = build_klass(:parafix, selected_db)
          expect(klass.new(filters: { q: 'First' }).results).to include(article_1)
          expect(klass.new(filters: { q: 'First' }).results).not_to include(article_2)
        end

        it "treats :confix as :circumfix" do
          klass = build_klass(:confix, selected_db)
          expect(klass.new(filters: { q: 'First' }).results).to include(article_1)
          expect(klass.new(filters: { q: 'First' }).results).not_to include(article_2)
        end

        it "treats :ambifix as :circumfix" do
          klass = build_klass(:ambifix, selected_db)
          expect(klass.new(filters: { q: 'First' }).results).to include(article_1)
          expect(klass.new(filters: { q: 'First' }).results).not_to include(article_2)
        end
      end
    end
  end
end
