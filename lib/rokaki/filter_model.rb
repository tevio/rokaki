# frozen_string_literal: true

module Rokaki
  module FilterModel
    include Filterable
    def self.included(base)
      base.extend(ClassMethods)
    end

    def prepare_terms(param, mode)
      if param.is_a? Array
        return param.map { |term| "%#{term}%" } if mode == :circumfix
        return param.map { |term| "%#{term}" } if mode == :prefix
        return param.map { |term| "#{term}%" } if mode == :suffix
      else
        return ["%#{param}%"] if mode == :circumfix
        return ["%#{param}"] if mode == :prefix
        return ["#{param}%"] if mode == :suffix
      end
    end


    module ClassMethods
      include Filterable::ClassMethods

      private

      def filter_map(model, query_key, options)
        filter_model(model)
        @filter_map_query_key = query_key

        @_filter_db = options[:db] || :postgres
        @_filter_mode = options[:mode] || :and
        like(options[:like]) if options[:like]
        ilike(options[:ilike]) if options[:ilike]
        filters(*options[:match]) if options[:match]
      end

      def filter(model, options)
        filter_model(model)
        @filter_map_query_key = nil

        @_filter_db = options[:db] || :postgres
        @_filter_mode = options[:mode] || :and
        like(options[:like]) if options[:like]
        ilike(options[:ilike]) if options[:ilike]
        filters(*options[:match]) if options[:match]
      end

      def filters(*filter_keys)
        if @filter_map_query_key
          define_filter_map(@filter_map_query_key, *filter_keys)
        else
          define_filter_keys(*filter_keys)
        end

        @_chain_filters ||= []
        filter_keys.each do |filter_key|
          # TODO: does the key need casting to an array here?
          _chain_filter(filter_key) unless filter_key.is_a? Hash
          _chain_nested_filter(filter_key) if filter_key.is_a? Hash
        end

        define_results # writes out all the generated filters
      end

      def like_filters(like_keys, term_type: :like)
        if @filter_map_query_key
          define_filter_map(@filter_map_query_key, *like_keys.call)
        else
          define_filter_keys(*like_keys.call)
        end

        @_chain_filters ||= []
        filter_map = []

        nested_like_filter = NestedLikeFilters.new(
          filter_key_object: like_keys,
          prefix: filter_key_prefix,
          infix: filter_key_infix,
          db: @_filter_db,
          type: term_type
        )
        nested_like_filter.call

        _chain_nested_like_filter(nested_like_filter)
        define_results # writes out all the generated filters
      end

      def _build_basic_filter(key)
        basic_filter = BasicFilter.new(
          keys: [key],
          prefix: filter_key_prefix,
          infix: filter_key_infix,
          like_semantics: @_like_semantics,
          i_like_semantics: @i_like_semantics,
          db: @_filter_db
        )
        basic_filter.call
        basic_filter
      end

      def _chain_filter(key)
        basic_filter = _build_basic_filter(key)
        class_eval basic_filter.filter_method, __FILE__, __LINE__ - 2

        @_chain_filters << basic_filter.filter_template
      end

      def _build_nested_filter(filters_object)
        nested_filter = NestedFilter.new(
          filter_key_object: filters_object,
          prefix: filter_key_prefix,
          infix: filter_key_infix,
          like_semantics: @_like_semantics,
          i_like_semantics: @i_like_semantics,
          db: @_filter_db
        )
        nested_filter.call
        nested_filter
      end

      def _chain_nested_like_filter(filters_object)
        filters_object.filter_methods.each do |filter_method|
          class_eval filter_method, __FILE__, __LINE__ - 2
        end

        filters_object.templates.each do |filter_template|
          @_chain_filters << filter_template
        end
      end

      def _chain_nested_filter(filters_object)
        nested_filter = _build_nested_filter(filters_object)

        nested_filter.filter_methods.each do |filter_method|
          class_eval filter_method, __FILE__, __LINE__ - 2
        end

        nested_filter.filter_templates.each do |filter_template|
          @_chain_filters << filter_template
        end
      end

      def filter_model(model_class)
        @model = (model_class.is_a?(Class) ? model_class : Object.const_get(model_class.capitalize))
        class_eval "def set_model; @model ||= #{@model}; end;"
      end

      def like(args)
        raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash
        @_like_semantics = (@_like_semantics || {}).merge(args)

        like_keys = LikeKeys.new(args)
        like_filters(like_keys, term_type: :like)
      end

      def ilike(args)
        raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash
        @i_like_semantics = (@i_like_semantics || {}).merge(args)

        like_keys = LikeKeys.new(args)
        like_filters(like_keys, term_type: :ilike)
      end

      # the model method is called to instatiate @model from the
      # filter_model method
      #
      def define_results
        results_def = 'def results; @model || set_model;'
        @_chain_filters.each do |item|
          results_def += item
        end
        results_def += '@model;end;'
        class_eval results_def, __FILE__, __LINE__
      end
    end
  end
end
