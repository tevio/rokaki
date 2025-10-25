# frozen_string_literal: true
require 'spec_helper'

module Rokaki
  RSpec.shared_examples "Filterable::FilterMapBlockDSL" do
    describe "Filterable block DSL" do
      let(:klass_simple) do
        Class.new do
          include Rokaki::Filterable

          filter_key_prefix :__

          filter_map do
            filters :date, author: [:first_name, :last_name]
          end

          attr_accessor :filters
          def initialize(filters: {})
            @filters = filters
          end
        end
      end

      let(:klass_nested) do
        Class.new do
          include Rokaki::Filterable

          filter_key_prefix :__

          filter_map do
            nested :author do
              filters :first_name
              nested :location do
                filters :city
              end
            end
          end

          attr_accessor :filters
          def initialize(filters: {})
            @filters = filters
          end
        end
      end

      it "defines simple filter accessors via filters inside block" do
        filters = { date: '2024-01-01', author: { first_name: 'Ada', last_name: 'Lovelace' } }
        obj = klass_simple.new(filters: filters)
        expect(obj.__date).to eq('2024-01-01')
        expect(obj.__author__first_name).to eq('Ada')
        expect(obj.__author__last_name).to eq('Lovelace')
      end

      it "defines nested accessors via nested + filters inside block" do
        filters = { author: { first_name: 'Ada', location: { city: 'London' } } }
        obj = klass_nested.new(filters: filters)
        expect(obj.__author__first_name).to eq('Ada')
        expect(obj.__author__location__city).to eq('London')
      end
    end
  end
end
