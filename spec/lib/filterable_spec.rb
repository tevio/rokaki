# frozen_string_literal: true

RSpec.describe Rokaki::Filterable do
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
        filter_key_1: %I[filter_key_2 filter_key_3]
      }
    end

    subject(:filterable) { ArrayFilterTest.new(filters: filters) }

    it 'defines the advanced key' do
      aggregate_failures do
        expect(filterable).to respond_to(:advanced__filter_key_1)
        expect(filterable).to respond_to(:advanced__filter_key_2)
      end
    end
  end
end
