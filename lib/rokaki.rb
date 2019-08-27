require "rokaki/version"

module Rokaki
  module Filterable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      private
      def define_filter_keys(*filter_keys)
        filter_keys.each do |filter_key|
          define_method filter_key, -> { filters[filter_key] }
        end
      end
    end

    def filters
      raise Error, "Filterable object must implement filters method that returns a hash"
    end
  end

  class Error < StandardError; end
  # Your code goes here...
end
