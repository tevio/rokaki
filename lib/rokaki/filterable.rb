# frozen_string_literal: true

module Rokaki
  # include this module for rokaki's filtering dsl in any object
  #
  module Filterable
    def self.included(base)
      base.extend(ClassMethods)
    end

    # class methods such as define_filter_keys which comprise the dsl
    #
    module ClassMethods
      private

      def define_filter_keys(*filter_keys)
        filter_keys.each do |filter_key|
          _build_filter([filter_key]) unless Hash === filter_key
          _nested_key filter_key if Hash === filter_key
        end
      end

      def define_filter_map(query_field, *filter_keys)
        filter_keys.each do |filter_key|
          _map_filters(query_field, [filter_key]) unless Hash === filter_key
          _nested_map query_field, filter_key if Hash === filter_key
        end
      end

      def define_query_key(key = nil)
        @filter_map_query_key = key
      end

      def filter_key_prefix(prefix = nil)
        @filter_key_prefix ||= prefix
      end

      def filter_key_infix(infix = :_)
        @filter_key_infix ||= infix
      end

      def or_key(or_key = :or)
        @or_key ||= or_key
      end

      def filterable_object_name(name = 'filters')
        @filterable_object_name ||= name
      end

      def _build_filter(keys)
        keys.delete(or_key)
        name    = @filter_key_prefix.to_s
        count   = keys.size - 1

        keys.each_with_index do |key, i|
          name += key.to_s
          name += filter_key_infix.to_s unless count == i
        end

        class_eval "def #{name}; #{filterable_object_name}.dig(*#{keys}); end;", __FILE__, __LINE__
      end

      def _map_filters(query_field, keys)
        keys.delete(or_key)
        name    = @filter_key_prefix.to_s
        count   = keys.size - 1

        keys.each_with_index do |key, i|
          name += key.to_s
          name += filter_key_infix.to_s unless count == i
        end

        class_eval "def #{name}; #{filterable_object_name}.dig(:#{query_field}); end;", __FILE__, __LINE__
      end

      def _nested_key(filters_object)
        filters_object.keys.each do |key|
          deep_map([key], filters_object[key]) { |keys| _build_filter(keys) }
        end
      end

      def _nested_map(query_field, filters_object)
        filters_object.keys.each do |key|
          deep_map([key], filters_object[key]) { |keys| _map_filters(query_field, keys) }
        end
      end

      def deep_map(keys, value, &block)
        if value.is_a? Hash
          value.keys.map do |key|
            _keys = keys.dup << key
            deep_map(_keys, value[key], &block)
          end
        end

        if value.is_a? Array
          value.each do |av|
            if av.is_a? Symbol
            _keys = keys.dup << av
            yield _keys
            else
              deep_map(keys, av, &block)
            end
          end
        end

        if value.is_a? Symbol
          _keys = keys.dup << value
          yield _keys
        end
      end

    end

    def filters
      raise Error, "Filterable object must implement 'filters' method that returns a hash"
    end

  end
end
