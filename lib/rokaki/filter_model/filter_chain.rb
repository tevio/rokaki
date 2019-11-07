# frozen_string_literal: true

module Rokaki
  module FilterModel
    class FilterChain
      def initialize(keys)
        @keys = keys
        @filter_chain = []
      end
    end
  end
end

