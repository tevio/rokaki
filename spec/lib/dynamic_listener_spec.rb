# frozen_string_literal: true

module Rokaki
  RSpec.shared_examples "Dynamic::RuntimeListener" do |selected_db|
    describe "Dynamic runtime listener (anonymous class)" do
      # Seed a richer dataset to assert different dynamic payloads produce different results
      let!(:ada)   { Author.create!(first_name: 'Kavya', last_name: 'Ndour') }
      let!(:alan)  { Author.create!(first_name: 'Mateo',  last_name: 'Okafor') }
      let!(:grace) { Author.create!(first_name: 'Yumi',  last_name: 'Chen') }

      let!(:a1) { Article.create!(title: 'The First Article',  content: 'Alpha and Omega',   published: DateTime.now,     author: ada) }
      let!(:a2) { Article.create!(title: 'Second Article',     content: 'Beta release',      published: DateTime.now + 1, author: ada) }
      let!(:a3) { Article.create!(title: 'On Computable Numbers', content: 'Foundations',    published: DateTime.now + 2, author: alan) }
      let!(:a4) { Article.create!(title: 'COBOL & Compilers',  content: 'Beta compiler',     published: DateTime.now + 3, author: grace) }

      def build_filter_model_listener(payload)
        Class.new do
          include Rokaki::FilterModel

          filter_model payload[:model], db: payload[:db]
          define_query_key payload[:query_key]

          filter_map do
            like payload[:like]
          end

          attr_accessor :filters
          def initialize(filters: {})
            @filters = filters
          end
        end
      end

      it "builds a FilterModel class at runtime and filters immediately" do
        payload = {
          model: :article,
          db: selected_db,
          query_key: :q,
          like: { title: :circumfix, author: { first_name: :prefix } }
        }

        listener = build_filter_model_listener(payload)
        results  = listener.new(filters: { q: 'First' }).results
        expect(results).to include(a1)
        expect(results).not_to include(a2, a3, a4)
      end

      context "range filters with dynamic listener" do
        let!(:t1) { Time.utc(2024,1,1,12,0,0) }
        let!(:t2) { Time.utc(2024,6,1,12,0,0) }
        let!(:t3) { Time.utc(2024,12,31,12,0,0) }

        let!(:r_a1) { Review.create!(title: 'R-A1', content: 'x', published: t1 + 9*24*3600, article: a1) }
        let!(:r_a2) { Review.create!(title: 'R-A2', content: 'y', published: t2 + 9*24*3600, article: a2) }
        let!(:r_a3) { Review.create!(title: 'R-A3', content: 'z', published: t3, article: a3) }

        def build_listener_with_ranges(model_sym)
          Class.new do
            include Rokaki::FilterModel
            filter_key_prefix :__
            filter_model model_sym, db: :sqlite # db overridden by selected_db when instantiated via payload paths below
            define_query_key :q
            filter_map do
              # enable fields to use range-style values at runtime
              if model_sym == :article
                filters :published
                nested :reviews do
                  filters :published
                end
              else
                # author with deep nested path: articles -> reviews.published
                nested :articles do
                  nested :reviews do
                    filters :published
                  end
                end
              end
            end
            attr_accessor :filters
            def initialize(filters: {}) ; @filters = filters ; end
          end
        end

        it "supports top-level between via Array [from,to] on article.published" do
          klass = build_listener_with_ranges(:article)
          a1.update!(published: t1)
          a2.update!(published: t2)
          a3.update!(published: t3)
          res = klass.new(filters: { published: [t1, t2] }).results
          expect(res).to include(a1, a2)
          expect(res).not_to include(a4)
        end

        it "supports deep nested between via Range on author.articles.reviews.published" do
          klass = build_listener_with_ranges(:author)
          # Expect authors that have at least one review in range [t1..t2]
          res = klass.new(filters: { articles: { reviews: { published: (t1..t2) } } }).results
          # ada has reviews r_a1 and r_a2 within range (through a1/a2)
          expect(res).to include(ada)
          # alan has r_a3 outside range, so excluded
          expect(res).not_to include(alan)
        end

        it "supports nested upper bound via max on article.reviews.published" do
          klass = build_listener_with_ranges(:article)
          res = klass.new(filters: { reviews: { published: { max: t2 } } }).results
          expect(res).to include(a1, a2)
          expect(res).not_to include(a3, a4)
        end
      end

      it "handles multiple payloads sequentially and returns different result sets" do
        # Payload A: match titles containing 'Article'
        payload_a = {
          model: :article,
          db: selected_db,
          query_key: :q,
          like: { title: :circumfix }
        }

        # Payload B: match author first_name prefix 'Al'
        payload_b = {
          model: :article,
          db: selected_db,
          query_key: :q,
          like: { author: { first_name: :prefix } }
        }

        # Payload C: match content suffix 'Beta'
        payload_c = {
          model: :article,
          db: selected_db,
          query_key: :q,
          like: { content: :suffix }
        }

        klass_a = build_filter_model_listener(payload_a)
        klass_b = build_filter_model_listener(payload_b)
        klass_c = build_filter_model_listener(payload_c)

        # A: Articles with 'Article' in title => a1, a2
        res_a = klass_a.new(filters: { q: 'Article' }).results
        expect(res_a).to include(a1, a2)
        expect(res_a).not_to include(a3, a4)

        # B: Authors with first_name starting with 'Al' => alan's articles => a3 only
        res_b = klass_b.new(filters: { q: 'Al' }).results
        expect(res_b).to include(a3)
        expect(res_b).not_to include(a1, a2, a4)

        # C: Content ending with 'Beta' => a4 content is 'Beta compiler' (does not end with Beta), a2 content 'Beta release' (does not end with Beta)
        # use 'release' suffix to hit a2, and 'compiler' suffix to hit a4 via two sequential runs
        res_c1 = klass_c.new(filters: { q: 'release' }).results
        expect(res_c1).to include(a2)
        expect(res_c1).not_to include(a1, a3, a4)

        res_c2 = klass_c.new(filters: { q: 'compiler' }).results
        expect(res_c2).to include(a4)
        expect(res_c2).not_to include(a1, a2, a3)
      end

      it "builds Filterable mapper classes at runtime for different payloads" do
        mapper_a = Class.new do
          include Rokaki::Filterable
          filter_key_prefix :__
          filter_map do
            filters :date, author: [:first_name]
          end
          attr_reader :filters
          def initialize(filters: {}) ; @filters = filters ; end
        end

        mapper_b = Class.new do
          include Rokaki::Filterable
          filter_key_prefix :__
          filter_map do
            nested :author do
              nested :location do
                filters :city
              end
            end
          end
          attr_reader :filters
          def initialize(filters: {}) ; @filters = filters ; end
        end

        f1 = mapper_a.new(filters: { date: '2025-01-01', author: { first_name: 'Alan' } })
        expect(f1.__date).to eq('2025-01-01')
        expect(f1.__author__first_name).to eq('Alan')

        f2 = mapper_b.new(filters: { author: { location: { city: 'London' } } })
        expect(f2.__author__location__city).to eq('London')
        # Ensure accessors differ across payloads (mapper_a lacks nested location accessors)
        expect { f1.__author__location__city }.to raise_error(NoMethodError)
      end
    end
  end
end
