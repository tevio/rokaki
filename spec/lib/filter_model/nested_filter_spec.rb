# frozen_string_literal: true

module Rokaki
  module FilterModel
    RSpec.shared_examples "FilterModel::NestedFilter" do |selected_db|
      describe NestedFilter do
        subject(:filter_generator) { described_class.new(**filter_args) }

        let(:filter_args) do
          {
            filter_key_object: filter_key_object,
            prefix: prefix,
            infix: infix,
            like_semantics: like_semantics,
            i_like_semantics: i_like_semantics,
            db: db
          }
        end

        let(:db) { selected_db }
        let(:filter_key_object) { { a: :a } }
        let(:prefix) { nil }
        let(:infix) { :_ }
        let(:like_semantics) { {} }
        let(:i_like_semantics) { {} }

        let(:expected_filter_method) do
          "def filter_a_a;" \
            "@model.joins(:a).where({ as: { a: a_a } });" \
            " end;"
        end

        let(:expected_filter_template) do
          "@model = filter_a_a if a_a;"
        end

        context 'with shallow keys' do
          it 'maps the keys' do
            filter_generator.call
            result = filter_generator

            aggregate_failures do
              expect(result.filter_methods).to eq([expected_filter_method])
              expect(result.filter_templates).to eq([expected_filter_template])
            end
          end

          context 'with custom fixations' do
            let(:prefix) { :_ }
            let(:infix) { :__ }

            let(:expected_filter_method) do
              "def _filter__a__a;" \
                "@model.joins(:a).where({ as: { a: _a__a } });" \
                " end;"
            end

            let(:expected_filter_template) do
              "@model = _filter__a__a if _a__a;"
            end

            it 'maps the keys' do
              filter_generator.call
              result = filter_generator

              aggregate_failures do
                expect(result.filter_methods).to eq([expected_filter_method])
                expect(result.filter_templates).to eq([expected_filter_template])
              end
            end
          end
        end

        context 'with deep keys' do
          context 'with basic filter type' do
            let(:filter_key_object) { { a: { b: { c: :d } } } }

            let(:expected_filter_method) do
              "def filter_a_b_c_d;" \
                "@model.joins(a: { b: :c }).where({ as: { bs: { cs: { d: a_b_c_d } } } });" \
                " end;"
            end

            let(:expected_filter_template) do
              "@model = filter_a_b_c_d if a_b_c_d;"
            end

            it 'maps the keys' do
              filter_generator.call
              result = filter_generator

              aggregate_failures do
                expect(result.filter_methods).to eq([expected_filter_method])
                expect(result.filter_templates).to eq([expected_filter_template])
              end
            end

            context 'with custom fixations' do
              let(:prefix) { :_ }
              let(:infix) { :__ }

              let(:expected_filter_method) do
                "def _filter__a__b__c__d;" \
                  "@model.joins(a: { b: :c }).where({ as: { bs: { cs: { d: _a__b__c__d } } } });" \
                  " end;"
              end

              let(:expected_filter_template) do
                "@model = _filter__a__b__c__d if _a__b__c__d;"
              end

              it 'maps the keys' do
                filter_generator.call
                result = filter_generator

                aggregate_failures do
                  expect(result.filter_methods).to eq([expected_filter_method])
                  expect(result.filter_templates).to eq([expected_filter_template])
                end
              end
            end
          end

          context 'with LIKE filter type' do
            let(:like_semantics) { { a: { b: { c: { d: :circumfix } } } } }
            let(:filter_key_object) { { a: { b: { c: :d } } } }

            let(:expected_filter_method) do
              if selected_db == :postgres
                "def filter_a_b_c_d;" \
                  "@model.joins(a: { b: :c }).where(\"cs.d LIKE ANY (ARRAY[?])\", prepare_terms(a_b_c_d, :circumfix));" \
                " end;"
              elsif selected_db == :mysql
                "def filter_a_b_c_d;" \
                  "@model.joins(a: { b: :c }).where(\"cs.d LIKE BINARY :query\", query: \"%\#{a_b_c_d}%\");" \
                  " end;"
              elsif selected_db == :sqlserver
                "def filter_a_b_c_d;" \
                  "sqlserver_like(@model.joins(a: { b: :c }), \"cs.d\", \"LIKE\", a_b_c_d, :circumfix);" \
                  " end;"
              elsif selected_db == :oracle
                "def filter_a_b_c_d;" \
                  "oracle_like(@model.joins(a: { b: :c }), \"cs.d\", \"LIKE\", a_b_c_d, :circumfix);" \
                  " end;"
              end
            end

            let(:expected_filter_template) do
              "@model = filter_a_b_c_d if a_b_c_d;"
            end

            it 'maps the keys' do
              filter_generator.call
              result = filter_generator

              aggregate_failures do
                expect(result.filter_methods).to eq([expected_filter_method])
                expect(result.filter_templates).to eq([expected_filter_template])
              end
            end

            context 'with custom fixations' do
              let(:prefix) { :_ }
              let(:infix) { :__ }

              let(:expected_filter_method) do
                case selected_db
                when :sqlite
                  "def _filter__a__b__c__d;" \
                    "@model.joins(a: { b: :c }).where(\"cs.d LIKE :query\", query: \"%\#{_a__b__c__d}%\");" \
                    " end;"
                when :postgres
                  "def _filter__a__b__c__d;" \
                    "@model.joins(a: { b: :c }).where(\"cs.d LIKE ANY (ARRAY[?])\", prepare_terms(_a__b__c__d, :circumfix));" \
                    " end;"
                when :mysql
                  "def _filter__a__b__c__d;" \
                    "@model.joins(a: { b: :c }).where(\"cs.d LIKE BINARY :query\", query: \"%\#{_a__b__c__d}%\");" \
                    " end;"
                when :sqlserver
                  "def _filter__a__b__c__d;" \
                    "sqlserver_like(@model.joins(a: { b: :c }), \"cs.d\", \"LIKE\", _a__b__c__d, :circumfix);" \
                    " end;"
                when :oracle
                  "def _filter__a__b__c__d;" \
                    "oracle_like(@model.joins(a: { b: :c }), \"cs.d\", \"LIKE\", _a__b__c__d, :circumfix);" \
                    " end;"
                end
              end

              let(:expected_filter_template) do
                "@model = _filter__a__b__c__d if _a__b__c__d;"
              end

              it 'maps the keys' do
                filter_generator.call
                result = filter_generator

                aggregate_failures do
                  expect(result.filter_methods).to eq([expected_filter_method])
                  expect(result.filter_templates).to eq([expected_filter_template])
                end
              end
            end
          end
        end
      end
    end
  end
end
