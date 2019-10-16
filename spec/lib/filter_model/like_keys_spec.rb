# frozen_string_literal: true

module Rokaki
  module FilterModel
    RSpec.describe LikeKeys do
      subject(:key_generator) { described_class.new(key_params) }

      context 'with shallow keys' do
        let(:key_params) { { name: :infix } }
        let(:expected_keys) { [:name] }

        it 'maps the keys' do
          expect(key_generator.call).to eq(expected_keys)
        end
      end

      context 'with one level of nested keys' do
        let(:key_params) { { author: { name: :infix } } }

        let(:expected_keys) { [{ author: [:name] }] }

        it 'maps the keys' do
          expect(key_generator.call).to eq(expected_keys)
        end
      end

      context 'with deeply nested keys' do
        let(:key_params) do
          {
            duration: {
              weekly: {
                article: {
                  author: {
                    name: :infix,
                    location: :suffix
                  }
                }
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
          {
            duration: {
              weekly: {
                article: {
                  author: [:name, :location]
                }
              }
            }
          },
          {
            book: {
              author: [:name, :location]
            }
          }
          ]
        }

        it 'maps the keys' do
          expect(key_generator.call).to eq(expected_keys)
        end
      end
    end
  end
end

