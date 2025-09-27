# frozen_string_literal: true

module Rokaki
  module FilterModel
    RSpec.shared_examples "FilterModel::LikeKeys" do |selected_db|
      describe LikeKeys do
        subject(:key_generator) { described_class.new(**args) }

        context 'with a shallow key' do
          let(:args) { { name: :infix } }
          let(:expected_keys) { [:name] }
          let(:expected_key_paths) { [[:name]] }

          it 'maps the keys' do
            expect(key_generator.call).to eq(expected_keys)
            expect(key_generator.key_paths).to eq(expected_key_paths)
          end
        end

        context 'with shallow keys' do
          let(:args) { { first_name: :infix, last_name: :circumfix } }
          let(:expected_keys) { [:first_name, :last_name] }
          let(:expected_key_paths) { [[:first_name], [:last_name]] }

          it 'maps the keys' do
            expect(key_generator.call).to eq(expected_keys)
            expect(key_generator.key_paths).to eq(expected_key_paths)
          end
        end

        context 'with one level of nested keys' do
          let(:args) { { author: { name: :infix } } }

          let(:expected_keys) { [{ author: :name }] }
          let(:expected_key_paths) { [[:author, :name]] }

          it 'maps the keys' do
            expect(key_generator.call).to eq(expected_keys)
            expect(key_generator.key_paths).to eq([[:author, :name]])
          end

          context 'each with leafs' do
            let(:args) do
              {
                articles: {
                  title: :circumfix,
                  reviews: {
                    title: :circumfix
                  }
                }
              }
            end

            let(:expected_keys) { [{ articles: :title }, { articles: { reviews: :title } }] }
            let(:expected_key_paths) { [[:articles, :title], [:articles, :reviews, :title]] }

            it 'maps the keys' do
              expect(key_generator.call).to eq(expected_keys)
              expect(key_generator.key_paths).to eq(expected_key_paths)
            end
          end
        end
        context 'with deeply nested keys' do
          let(:args) do
            {
              duration: {
                duration_title: :circumfix,
                weekly: {
                  weekly_title: :circumfix,
                  article: {
                    author: {
                      name: :infix,
                      location: :suffix
                    }
                  },
                  weekly_digest: :suffix
                }
              },
              book: {
                author: {
                  name: :infix,
                  location: :suffix
                }
              }
            }
          end

          let(:expected_keys) {
            [
              { duration: :duration_title },
              { duration: { weekly: :weekly_title } },
              { duration: { weekly: { article: { author: :name } } } },
              { duration: { weekly: { article: { author: :location } } } },
              { duration: { weekly: :weekly_digest } },
              { book: { author: :name } },
              { book: { author: :location } }
            ]
          }

          it 'maps the keys' do
            expect(key_generator.call).to eq(expected_keys)
            expect(key_generator.key_paths).to eq([
              [:duration, :duration_title],
              [:duration, :weekly, :weekly_title],
              [:duration, :weekly, :article, :author, :name],
              [:duration, :weekly, :article, :author, :location],
              [:duration, :weekly, :weekly_digest],
              [:book, :author, :name],
              [:book, :author, :location]
            ])
          end
        end
      end
    end
  end
end

