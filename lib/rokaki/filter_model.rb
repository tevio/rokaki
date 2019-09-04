# frozen_string_literal: true

module Rokaki
  module FilterModel
    include Filterable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      include Filterable::ClassMethods

      private

      def filters(*filter_keys)
        define_filter_keys *filter_keys

        @_chain_filters = []
        filter_keys.each do |filter_key|
          _chain_filter(filter_key) unless filter_key.is_a? Hash
          _chain_nested filter_key if filter_key.is_a? Hash
        end

        define_results
      end

      def _chain_filter(key)
        filter = "#{filter_key_prefix}#{key}"
        class_eval "def #{filter_key_prefix}filter_#{key};" \
                   "#{_chain_filter_type(key)} end;",
                   __FILE__, __LINE__ - 2

        @_chain_filters << "@model = #{filter_key_prefix}filter_#{key} if #{filter};"
      end

      def _chain_filter_type(key)
        filter = "#{filter_key_prefix}#{key}"

        query = ""
        if @_like_semantics && mode = @_like_semantics[key]
          query = "@model.where(\"#{key} LIKE :query\", "
          if mode == :circumfix
            query += "query: \"%\#{#{filter}}%\")"
          end
          if mode == :prefix
            query += "query: \"%\#{#{filter}}\")"
          end
          if mode == :suffix
            query += "query: \"\#{#{filter}}%\")"
          end
        else
          query = "@model.where(#{filter}: #{key})"
        end
        "#{query};"
      end

      def _build_deep_chain(keys)
        name    = filter_key_prefix.to_s
        count   = keys.size - 1

        joins = ''
        where = ''
        out   = ''

        leaf = keys.pop

        keys.each_with_index do |key, _i|
          next unless keys.length == 1
          name  = "#{filter_key_prefix}#{key}#{filter_key_infix}#{leaf}"
          joins = ":#{key}"

          where = "{ #{key.to_s.pluralize}: { #{leaf}: #{name} } }"
        end


        joins = joins += out
        where = where += out

        class_eval "def #{filter_key_prefix.to_s}filter_#{name};"\
                   "@model.joins(#{joins}).where(#{where}); end;",
                   __FILE__, __LINE__ - 2

        @_chain_filters << "@model = #{filter_key_prefix}filter_#{name} if #{name};"
      end

      def _chain_nested(filters_object)
        filters_object.keys.each do |key|
          deep_chain([key], filters_object[key])
        end
      end

      def associated_table(association)
        @model.reflect_on_association(association).klass.table_name
      end

      def filter_model(model)
        @model = model
      end

      def like(args)
        raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash
        @_like_semantics = (@_like_semantics || {}).merge(args)
      end

      def deep_chain(keys, value)
        if value.is_a? Hash
          value.keys.map do |key|
            _keys = keys.dup << key
            deep_chain(_keys, value[key])
          end
        end

        if value.is_a? Array
          value.each do |av|
            _keys = keys.dup << av
            _build_deep_chain(_keys)
          end
        end

        if value.is_a? Symbol
          _keys = keys.dup << value
          _build_deep_chain(_keys)
        end
      end

      def define_results
        results_def = 'def results;'
        @_chain_filters.each do |item|
          results_def += item
        end
        results_def += '@model;end;'
        class_eval results_def, __FILE__, __LINE__
      end
    end
  end
end
