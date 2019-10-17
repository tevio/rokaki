# frozen_string_literal: true

require 'sqlite3'
require 'active_record'

# Use `binding.pry` anywhere in this script for easy debugging
require 'pry'

# Connect to an in-memory sqlite3 database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Define a minimal database schema
ActiveRecord::Schema.define do
  create_table :authors, force: true do |t|
    t.string :first_name
    t.string :last_name
  end

  create_table :articles, force: true do |t|
    t.string :title
    t.string :content
    t.datetime :published
    t.belongs_to :author, index: true
  end
end

# Define the models
class Author < ActiveRecord::Base
  has_many :articles, inverse_of: :author
end

class Article < ActiveRecord::Base
  belongs_to :author, inverse_of: :articles, required: true
end

module Rokaki
  RSpec.describe FilterModel do
    let(:author_1_first_name) { 'Shteevie' }
    let(:author_1_last_name) { 'Martini' }

    let(:article_1_title) { 'Article 1 Title' }
    let(:article_1_content) { 'Article 1 Content' }
    let(:article_1_published) { DateTime.now }

    let(:article_titles) do
      ['Article 0 Title',
       'Article 1 Title',
       'Article 2 Title',
       'Article 3 Title',
       'Article 4 Title']
    end

    let(:article_contents) do
      ['Article Contents 0',
       'Article Contents 1',
       'Article Contents 2',
       'Article Contents 3',
       'Article Contents 4']
    end

    let(:article_published) do
      [
        DateTime.now,
        DateTime.now + 1 .day,
        DateTime.now + 2 .days,
        DateTime.now + 3 .days,
        DateTime.now + 4 .days
      ]
    end

    let(:article_1_content) { 'Article 1 Content' }
    let(:article_1_published) { DateTime.now }

    let(:author_2_first_name) { 'Marvin' }
    let(:author_2_last_name) { 'Shimmy' }

    let(:author_1) do
      Author.create!(
        first_name: author_1_first_name,
        last_name: author_1_last_name
      )
    end

    let!(:article_1_auth_1) do
      Article.create!(
        title: article_titles[1],
        content: article_contents[1],
        published: article_published[1],
        author: author_1
      )
    end

    let!(:article_2_auth_1) do
      Article.create!(
        title: article_titles[2],
        content: article_contents[2],
        published: article_published[2],
        author: author_1
      )
    end

    let(:author_2) do
      Author.create!(
        first_name: author_2_first_name,
        last_name: author_2_last_name
      )
    end

    let!(:article_3_auth_2) do
      Article.create!(
        title: article_titles[2],
        content: article_contents[2],
        published: article_published[2],
        author: author_2
      )
    end

    context 'filter simple' do
      let(:dummy_class) do
        Class.new do
          include FilterModel

          filter_key_prefix :__
          filter_model :article
          filters :title

          attr_accessor :filters

          def initialize(filters:, model:)
            @filters = filters
            @model = model
          end
        end
      end

      let(:filters) do
        {
          title: article_titles[1]
        }
      end

      it 'returns the simple filtered item' do
        test = dummy_class.new(filters: filters, model: Article)
        expect(test.results).to contain_exactly(article_1_auth_1)
      end
    end

    context 'filter single layer relation' do
      let(:dummy_class) do
        Class.new do
          include FilterModel

          filter_key_prefix :__
          filter_model :article
          filters :date, :title, author: %i[first_name last_name]

          attr_accessor :filters

          def initialize(filters:, model:)
            @filters = filters
            @model = model
          end
        end
      end

      let(:filters) do
        {
          author: {
            first_name: author_1_first_name
          }
        }
      end

      it 'returns the filtered item' do
        test = dummy_class.new(filters: filters, model: Article)
        aggregate_failures do
          expect(test.results).to include(article_1_auth_1, article_2_auth_1)
          expect(test.results).not_to include(article_3_auth_2)
        end
      end
    end

    context 'filter simple circumfix partial match with like keyword' do
      let(:dummy_class) do
        Class.new do
          include FilterModel

          # filter_model :article
          # like title: :circumfix
          filter :article, like: { title: :circumfix }

          attr_accessor :filters

          def initialize(filters:, model:)
            @filters = filters
            @model = model
          end
        end
      end

      let(:article_1_title) { 'ticle 1' }

      let(:filters) do
        {
          title: article_1_title
        }
      end

      it 'returns the filtered item' do
        test = dummy_class.new(filters: filters, model: Article)
        aggregate_failures do
          expect(test.results).to include(article_1_auth_1)
          expect(test.results).not_to include(article_2_auth_1, article_3_auth_2)
        end
      end
    end

    context 'filter complex circumfix partial match with like keyword' do
      context 'using the porcelain syntax' do
        let(:dummy_class) do
          Class.new do
            include FilterModel

            like author: {
                  first_name: :circumfix,
                  last_name: :circumfix
                }
            filters :title, :created_at, author: [:first_name, :last_name]
            filter_model :article

            attr_accessor :filters

            def initialize(filters:)
              @filters = filters
            end
          end
        end

        context 'when only the author first name filter is passed' do
          let(:author_1_first_name) { 'teev' }

          let(:filters) do
            {
              author: {
                first_name: author_1_first_name
              }
            }
          end

          it 'returns the filtered item' do
            test = dummy_class.new(filters: filters)
            aggregate_failures do
              expect(test.results).to include(article_1_auth_1)
              expect(test.results).not_to include(article_3_auth_2)
            end
          end
        end

        context 'when the author first name and a non matching title are passed' do
          let(:author_1_first_name) { 'teev' }

          let(:filters) do
            {
              author: {
                first_name: author_1_first_name
              },
              title: article_titles[3]
            }
          end

          it 'returns no results' do
            test = dummy_class.new(filters: filters)
            aggregate_failures do
              expect(test.results).to be_empty
            end
          end
        end
      end

      context 'using the "filter" keyword syntax' do
        let(:dummy_class) do
          Class.new do
            include FilterModel

            filter :article,
              like: {
              author: {
                first_name: :circumfix,
                last_name: :circumfix
              }
            },
            match: %i[title created_at]

            attr_accessor :filters

            def initialize(filters:)
              @filters = filters
            end
          end
        end

        context 'when only the author first name filter is passed' do
          let(:author_1_first_name) { 'teev' }

          let(:filters) do
            {
              author: {
                first_name: author_1_first_name
              }
            }
          end

          it 'returns the filtered item' do
            test = dummy_class.new(filters: filters)
            aggregate_failures do
              expect(test.results).to include(article_1_auth_1)
              expect(test.results).not_to include(article_3_auth_2)
            end
          end
        end

        context 'when the author first name and a non matching title are passed' do
          let(:author_1_first_name) { 'teev' }

          let(:filters) do
            {
              author: {
                first_name: author_1_first_name
              },
              title: article_titles[3]
            }
          end

          it 'returns no results' do
            test = dummy_class.new(filters: filters)
            aggregate_failures do
              expect(test.results).to be_empty
            end
          end
        end
      end
    end
  end
end
