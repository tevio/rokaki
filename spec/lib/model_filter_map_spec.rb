# frozen_string_literal: true
require 'spec_helper'
# require 'support/active_record_setup'

module Rokaki
  RSpec.shared_examples "FilterModel#filter_map" do |selected_db|
    describe "filter_map" do
      let(:author_1_first_name) { 'Shteevine' }
      let(:author_1_last_name) { 'Martini' }

      let(:author_2_first_name) { 'Jimi' }
      let(:author_2_last_name) { 'Hendrix' }

      let(:author_3_first_name) { 'Alan' }
      let(:author_3_last_name) { 'Partridge' }

      let(:author_4_first_name) { 'Ada' }
      let(:author_4_last_name) { 'Lovilace' }

      let(:article_titles) do
        ['Article 0 Title',
         'The First Article',
         'The Second Preview Article',
         'The Third Article',
         'Article 4 Title']
      end

      let(:article_contents) do
        ['Article Contents 0',
         'Contents of the First Article review pending',
         'The second articles contents not the First Article',
         'The article of thirdness',
         'Article Contents 4']
      end

      let(:review_titles) do
        [
          'Review 0',
          'The Review 1',
          'Article Review 2',
          'Some Review 3'
        ]
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

      let!(:author_1) do
        Author.create!(
          first_name: author_1_first_name,
          last_name: author_1_last_name
        )
      end

      let!(:author_2) do
        Author.create!(
          first_name: author_2_first_name,
          last_name: author_2_last_name
        )
      end

      let!(:author_3) do
        Author.create!(
          first_name: author_3_first_name,
          last_name: author_3_last_name
        )
      end

      let!(:author_4) do
        Author.create!(
          first_name: author_4_first_name,
          last_name: author_4_last_name
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

      let!(:article_2_auth_2) do
        Article.create!(
          title: article_titles[2],
          content: article_contents[2],
          published: article_published[2],
          author: author_2
        )
      end

      let!(:article_3_auth_3) do
        Article.create!(
          title: article_titles[3],
          content: article_contents[3],
          published: article_published[3],
          author: author_3
        )
      end

      let!(:review_1) do
        Review.create(title: review_titles[1], article: article_1_auth_1)
      end

      let!(:review_2) do
        Review.create(title: review_titles[2], article: article_2_auth_2)
      end

      context 'using porcelain syntax' do
        context 'with define_query_key and like' do
          let(:filters) do
            {
              query: 'First'
            }
          end

          context 'with an AND' do
            let(:dummy_class) do
              Class.new do
                include FilterModel

                filterable_object_name :fylterz
                filter_key_prefix :__
                filter_model :article, db: selected_db

                define_query_key :query # must be decalred before the filter ('like' n this case)
                like title: :circumfix, content: :circumfix

                attr_accessor :fylterz

                def initialize(fylterz:)
                  @fylterz = fylterz
                end
              end
            end


            it 'returns the simple filtered item' do
              test = dummy_class.new(fylterz: filters)
              expect(test.results).to contain_exactly(article_1_auth_1)
            end
          end

          context 'with an OR' do
            let(:dummy_class) do
              Class.new do
                include FilterModel

                filter_key_prefix :__
                filter_model :article, db: selected_db

                define_query_key :query # must be decalred before the filter ('like' n this case)
                like title: :circumfix, or: { content: :circumfix }

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
              end
            end

            it 'returns filtered items' do
              test = dummy_class.new(filters: filters)
              expect(test.results).to include(article_1_auth_1, article_2_auth_2)
              expect(test.results).not_to include(article_3_auth_3)
            end
          end

          context 'with an OR specified via a custom .or_key' do
            let(:dummy_class) do
              Class.new do
                include FilterModel

                or_key :oared
                filter_key_prefix :__
                filter_model :article, db: selected_db

                define_query_key :query # must be decalred before the filter ('like' n this case)
                like title: :circumfix, oared: { content: :circumfix }

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
              end
            end

            it 'returns filtered items' do
              test = dummy_class.new(filters: filters)
              expect(test.results).to include(article_1_auth_1, article_2_auth_2)
              expect(test.results).not_to include(article_3_auth_3)
            end
          end
        end
      end

      context 'using filter_map command' do
        context 'with a simple query structure' do
          context 'when using an AND' do
            let(:dummy_class) do
              Class.new do
                include FilterModel

                filter_map :author, :query, like: { first_name: :circumfix, last_name: :circumfix }, db: selected_db

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
              end
            end

            let(:filters) do
              { query: 'in' }
            end

            it 'returns all authors who have a first and last name that share the same string' do
              test = dummy_class.new(filters: filters)

              aggregate_failures do
                expect(test.results).to include(author_1)
                expect(test.results).not_to include(author_2, author_3)
              end
            end
          end

          context 'when using an OR' do
            let(:dummy_class) do
              Class.new do
                include FilterModel

                filter_map :author, :query, like: { first_name: :circumfix, or: { last_name: :circumfix } }, db: selected_db

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
              end
            end

            let(:filters) do
              { query: 'vi' }
            end

            it 'returns all authors who have a first and last name that share the same string' do
              test = dummy_class.new(filters: filters)

              aggregate_failures do
                expect(test.results).to include(author_1, author_4)
                expect(test.results).not_to include(author_2, author_3)
              end
            end
          end
        end

        context 'filter the specified field "query" by ALL specified fields in like key' do
          let(:dummy_class) do
            Class.new do
              include FilterModel

              filter_map :author, :query,
                like: {
                  articles: {
                    title: :circumfix,
                    reviews: {
                      title: :circumfix
                    }
                  },
                }, db: selected_db

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
            end
          end

          let(:filters) do
            { query: 'eview ' }
          end

          it 'returns all authors who have an article with a review that contain the same words in the title' do
            test = dummy_class.new(filters: filters)

            aggregate_failures do
              expect(test.results).to include(author_2)
              expect(test.results).not_to include(author_3)
            end
          end
        end

        context 'filter the specified field "query" by ANY specified fields in like key' do
          let(:dummy_class) do
            Class.new do
              include FilterModel

              filter_map :author, :query,
                like: {
                  articles: {
                    title: :circumfix,
                    or: {
                      reviews: {
                        title: :circumfix,
                        content: :circumfix
                      }
                    },
                    content: :circumfix
                  },
                }, db: selected_db

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
            end
          end

          let(:filters) do
            { query: 'eview ' }
          end

          it 'returns all authors who have an article with a review that contain the same words in the title' do
            test = dummy_class.new(filters: filters)

            aggregate_failures do
              expect(test.results).to include(author_1)
              expect(test.results).not_to include(author_2)
            end
          end
        end

        context 'filter the specified field "query" by all specified fields in LIKE key' do
          let(:dummy_class) do
            Class.new do
              include FilterModel

              filter_map :author, :query,
                like: {
                  articles: {
                    title: :suffix,
                    reviews: {
                      title: :suffix
                    }
                  },
                }, db: selected_db

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
            end
          end

          let(:filters) do
            { query: 'The' }
          end

          it 'returns authors who have an article with a review that start with same words in the title' do
            test = dummy_class.new(filters: filters)

            aggregate_failures do
              expect(test.results).to include(author_1)
              expect(test.results).not_to include(author_3, author_2)
            end
          end
        end

        context 'filter the specified field "query" by all specified fields in ILIKE key' do
          let(:dummy_class) do
            Class.new do
              include FilterModel

              filter_map :author, :query,
                ilike: {
                  articles: {
                    title: :suffix,
                    reviews: {
                      title: :suffix
                    }
                  },
                }, db: selected_db

                attr_accessor :filters

                def initialize(filters:)
                  @filters = filters
                end
            end
          end

          let(:filters) do
            { query: 'tHe' }
          end

          it 'returns both authors who have an article with a review that start with same words in the title' do
            test = dummy_class.new(filters: filters)

            aggregate_failures do
              expect(test.results).to include(author_1)
              expect(test.results).not_to include(author_3, author_2)
            end
          end
        end
      end
    end
  end
end
