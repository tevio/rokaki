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

      # --- Block DSL support (Filterable mode) ---
      def nested(name, &blk)
        if instance_variable_defined?(:@__in_filterable_block) && @__in_filterable_block
          raise ArgumentError, 'nested requires a symbol name' unless name.is_a?(Symbol)
          @__ctx_stack << name
          instance_eval(&blk) if blk
          @__ctx_stack.pop
        else
          raise NoMethodError, 'nested can only be used inside filter_map block'
        end
      end

      # In Filterable, `filter_map` without args opens a block to declare `filters` with optional nesting
      # For backward compatibility, if args are provided, delegate to define_filter_map
      def filter_map(*args, &block)
        if block_given? && args.empty?
          # Enter block-collection mode
          @__in_filterable_block = true
          @__ctx_stack = []
          @__block_filters = []

          instance_eval(&block)

          # Materialize collected filters
          unless @__block_filters.empty?
            define_filter_keys(*@__block_filters)
          end

          # cleanup
          @__in_filterable_block = false
          @__ctx_stack = nil
          @__block_filters = nil
          return
        end

        # Positional/legacy map form (delegates to define_filter_map)
        if args.any?
          query_field, *filter_keys = args
          define_filter_map(query_field, *filter_keys)
        end
      end

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

      def filter_key_infix(infix = :__)
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

      # Helper: wrap a Symbol/Hash filter key in current nested context
      def wrap_in_context(filter_key)
        return filter_key unless instance_variable_defined?(:@__ctx_stack) && @__ctx_stack && !@__ctx_stack.empty?
        ctx = @__ctx_stack.dup
        if filter_key.is_a?(Hash)
          # Nest the entire hash under the context chain
          ctx.reverse.inject(filter_key) { |acc, k| { k => acc } }
        else
          # Symbol → build a hash with leaf
          ctx.reverse.inject(filter_key) { |acc, k| { k => acc } }
        end
      end

      public

      # Enhance `filters` to support block mode accumulation
      def filters(*filter_keys)
        if instance_variable_defined?(:@__in_filterable_block) && @__in_filterable_block
          @__block_filters ||= []
          @__ctx_stack ||= []
          filter_keys.each do |fk|
            @__block_filters << wrap_in_context(fk)
          end
          return
        end

        define_filter_keys(*filter_keys)
      end

    end

    def filters
      raise Error, "Filterable object must implement 'filters' method that returns a hash"
    end

  end
end
