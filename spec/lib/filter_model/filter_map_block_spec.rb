# frozen_string_literal: true
require 'spec_helper'

module Rokaki
  RSpec.shared_examples "FilterModel::FilterMapBlockDSL" do |selected_db|
    describe "filter_map block DSL" do
      it "currently is not supported (calling filter_map with a block raises an ArgumentError)" do
        expect do
          Class.new do
            include FilterModel

            filter_key_prefix :__

            # This is the DSL in question (note: no args to filter_map)
            filter_map do
              like title: :circumfix
              nested :author do
                like first_name: :prefix
              end
            end

            attr_accessor :filters
            def initialize(filters: {})
              @filters = filters
            end
          end
        end.to raise_error(ArgumentError)
      end
    end
  end
end
