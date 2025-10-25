# frozen_string_literal: true

module Rokaki
  module FilterModel
    RSpec.shared_examples "FilterModel::BasicFilter" do |selected_db|
      describe BasicFilter do
        subject(:filter_generator) { described_class.new(**filter_args) }

        let(:filter_args) do
          {
            keys: keys,
            prefix: prefix,
            infix: infix,
            like_semantics: like_semantics,
            i_like_semantics: i_like_semantics,
            db: db
          }
        end

        let(:db) { selected_db }
        let(:keys) { [:a] }
        let(:prefix) { nil }
        let(:infix) { :_ }
        let(:like_semantics) { {} }
        let(:i_like_semantics) { {} }

        let(:expected_filter_method) do
          "def filter_a;@model.where(a: a) end;"
        end

        let(:expected_filter_template) do
          "@model = filter_a if a;"
        end

        context 'with shallow keys' do
          context 'with basic semantics' do
            it 'maps the keys' do
              filter_generator.call
              result = filter_generator

              aggregate_failures do
                expect(result.filter_method).to eq(expected_filter_method)
                expect(result.filter_template).to eq(expected_filter_template)
              end
            end
          end

          context 'with LIKE semantics' do
            let(:expected_filter_method) do
              case selected_db
              when :sqlite
                "def filter_a;" \
                  "@model.where(\"a LIKE :query\"," \
                  " query: \"%\#{a}\")" \
                  " end;"
              when :postgres
                "def filter_a;@model.where(\"a LIKE ANY (ARRAY[?])\", prepare_terms(a, :prefix)) end;"
              when :mysql
                "def filter_a;@model.where(\"a LIKE BINARY :query\", query: \"%\#{a}\") end;"
              when :sqlserver
                "def filter_a;sqlserver_like(@model, \"a\", \"LIKE\", a, :prefix) end;"
              end
            end

            let(:like_semantics) { {a: :prefix} }

            it 'maps the keys' do
              filter_generator.call
              result = filter_generator

              aggregate_failures do
                expect(result.filter_method).to eq(expected_filter_method)
                expect(result.filter_template).to eq(expected_filter_template)
              end
            end
          end

        end
      end
    end
  end
end
