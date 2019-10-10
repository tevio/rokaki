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

      def filter(model, options)
        filter_model(model)

        like(options[:like]) if options[:like]
        filters(*options[:match]) if options[:match]
      end

      def filters(*filter_keys)
        define_filter_keys *filter_keys

        @_chain_filters ||= []
        filter_keys.each do |filter_key|
          _chain_filter([filter_key]) unless filter_key.is_a? Hash
          _chain_nested(filter_key) if filter_key.is_a? Hash
        end

        define_results
      end

      def _chain_filter(keys)
        first_key = keys.shift
        filter = "#{filter_key_prefix}#{first_key}"
        name = first_key

        keys.each do |key|
          filter += "#{filter_key_infix}#{key}"
          name += "#{filter_key_infix}#{key}"
        end

        filter_method = "def #{filter_key_prefix}filter_#{name};" \
          "#{_chain_filter_type(name)} end;"

        class_eval filter_method, __FILE__, __LINE__ - 2

        @_chain_filters << "@model = #{filter_key_prefix}filter_#{name} if #{filter};"
      end

      def _chain_filter_type(key)
        filter = "#{filter_key_prefix}#{key}"

        query = ''
        if @_like_semantics && mode = @_like_semantics[key]
          query = "@model.where(\"#{key} LIKE :query\", "
          query += "query: \"%\#{#{filter}}%\")" if mode == :circumfix
          query += "query: \"%\#{#{filter}}\")" if mode == :prefix
          query += "query: \"\#{#{filter}}%\")" if mode == :suffix
        else
          query = "@model.where(#{filter}: #{key})"
        end

        query
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

        # chain filter here?
        #
        filter_method = "def #{filter_key_prefix}filter_#{name};"\
                   "@model.joins(#{joins}).where(#{where}); end;"

        class_eval filter_method, __FILE__, __LINE__ - 2

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
        @model = (model.is_a?(Class) ? model : Object.const_get(model.capitalize))
        class_eval "def model; @model ||= #{@model}; end;"
      end

      def like(args)
        raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash

        like_keys = {base: []}
        args.keys.each do |key|
          map_like_keys(like_keys, args, key)
        end

        @_like_semantics = (@_like_semantics || {}).merge(args)

        base_keys = like_keys.delete(:base)
        key_results = base_keys << like_keys

        filters(*key_results)
      end

      def map_like_keys(key_result, base_object, key)
        sub_object = base_object[key]
        if sub_object.is_a? Hash
          sub_object.keys.each do |sub_key|
            sub_object_value = sub_object[sub_key]
            if sub_object_value.is_a? Symbol
              if key_result[key].is_a? Array
                key_result[key] << sub_key
              else
                key_result[key] = [sub_key]
              end
            elsif sub_object_value.is_a? Hash
              map_like_keys(key_result, sub_object, sub_key)
            end
          end
        elsif sub_object.is_a? Symbol
          key_result[:base] << key
        end
        key_result
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

      # the model method is called to instatiate @model from the
      # filter_model method
      #
      def define_results
        results_def = 'def results;model;'
        @_chain_filters.each do |item|
          results_def += item
        end
        results_def += '@model;end;'
        class_eval results_def, __FILE__, __LINE__
      end
    end
  end
end
