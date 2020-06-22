# frozen_string_literal: true
require 'spec_helper'

module Rokaki
  RSpec.describe Filterable do
    context '#define_filter_map' do
      class FilterMapTest
        include Rokaki::Filterable

        def initialize(fylterz:)
          @fylterz = fylterz
        end
        attr_accessor :fylterz

        filterable_object_name :fylterz
        filter_key_prefix :__
        define_filter_map :query, :mapped_a, association: :field
      end

      subject(:filterable) { FilterMapTest.new(fylterz: filters) }
      let(:filters) { { query: 'wat' } }

      it 'maps the basic filter keys' do
        expect(filterable).to respond_to(:__mapped_a)
        expect(filterable.__mapped_a).to eq('wat')
      end

      it 'maps the advanced key' do
        expect(filterable).to respond_to(:__association_field)
        expect(filterable.__association_field).to eq('wat')
      end
    end

    context '#define_filter_keys' do
      class FilterTest
        include Rokaki::Filterable

        def initialize(filters:)
          @filters = filters
        end
        attr_accessor :filters

        filter_key_prefix :__
        define_filter_keys :basic, advanced: :filter_key
      end


      subject(:filterable) { FilterTest.new(filters: filters) }
      let(:filters) { {} }

      it 'defines the basic filter keys' do
        expect(filterable).to respond_to(:__basic)
      end

      it 'defines the advanced key' do
        expect(filterable).to respond_to(:__advanced_filter_key)
      end

      context 'when advanced key has an array' do
        class ArrayFilterTest
          include Rokaki::Filterable

          def initialize(filters:)
            @filters = filters
          end
          attr_accessor :filters

          filter_key_infix :__
          define_filter_keys :basic, advanced: [:filter_key_1, :filter_key_2]
        end

        subject(:filterable) { ArrayFilterTest.new(filters: filters) }

        it 'defines the advanced key' do
          aggregate_failures do
            expect(filterable).to respond_to(:advanced__filter_key_1)
            expect(filterable).to respond_to(:advanced__filter_key_2)
          end
        end
      end

      context 'when advanced key has an advanced key' do
        class AdvancedFilterTest
          include Rokaki::Filterable

          def initialize(filters:)
            @filters = filters
          end
          attr_accessor :filters

          filter_key_infix :__
          define_filter_keys :basic, advanced: {
            filter_key_1: [:filter_key_2, { filter_key_3: :deep_node }],
            filter_key_4: :simple_leaf_array
          }
        end

        subject(:filterable) { AdvancedFilterTest.new(filters: filters) }
        let(:filters) {
          {
            basic: 'ABC',
            advanced: {
              filter_key_1: {
                filter_key_2: '123',
                filter_key_3: { deep_node: 'NODE' }
              },
              filter_key_4: { simple_leaf_array: [1,2,3,4] }
            }
          }
        }

        it 'defines the advanced key' do
          aggregate_failures do
            expect(filterable).to respond_to(:advanced__filter_key_1__filter_key_2)
            expect(filterable.advanced__filter_key_1__filter_key_2).to eq('123')

            expect(filterable).to respond_to(:advanced__filter_key_1__filter_key_3__deep_node)
            expect(filterable.advanced__filter_key_1__filter_key_3__deep_node).to eq('NODE')

            expect(filterable).to respond_to(:advanced__filter_key_4__simple_leaf_array)
            expect(filterable.advanced__filter_key_4__simple_leaf_array).to eq([1,2,3,4])
          end
        end
      end
    end
  end
end
