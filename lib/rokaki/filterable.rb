module Rokaki
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
          _build_filter([filter_key]) unless filter_key.is_a? Hash
          _nested_key filter_key if filter_key.is_a? Hash
        end
      end

      def filter_key_prefix(prefix)
        @filter_key_prefix ||= prefix
      end

      def filter_key_infix(infix = :_)
        @filter_key_infix ||= infix
      end

      def _build_filter(keys)
        name    = @filter_key_prefix.to_s
        filters = "filters"
        count   = keys.size - 1

        keys.each_with_index do |key, i|
          name += key.to_s
          name += filter_key_infix.to_s unless count == i

          filters += "[:#{key}]"
        end

        class_eval "def #{name}; filters.dig(*#{keys}); end;", __FILE__, __LINE__
      end

      def _nested_key(filters_object)
        filters_object.keys.each do |key|
          deep_map([key], filters_object[key])
        end
      end

      def deep_map(keys, value)
        if value.is_a? Hash
          value.keys.map do |key|
            _keys = keys.dup << key
            deep_map(_keys, value[key])
          end
        end

        if value.is_a? Array
          value.each do |av|
            _keys = keys.dup << av
            _build_filter(_keys)
          end
        end

        if value.is_a? Symbol
          _keys = keys.dup << value
          _build_filter(_keys)
        end
      end

    end

    def filters
      raise Error, "Filterable object must implement 'filters' method that returns a hash"
    end

  end
end
