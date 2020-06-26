# frozen_string_literal: true
require 'active_support/inflector'

module Rokaki
  module FilterModel
    class NestedFilter
      def initialize(filter_key_object:, prefix:, infix:, like_semantics:, i_like_semantics:, db:, mode: :and)
        @filter_key_object = filter_key_object
        @prefix = prefix
        @infix = infix
        @like_semantics = like_semantics
        @i_like_semantics = i_like_semantics
        @filter_methods = []
        @filter_templates = []
        @db = db
        @mode = mode
      end
      attr_reader :filter_key_object, :prefix, :infix, :like_semantics, :i_like_semantics, :db, :mode
      attr_accessor :filter_methods, :filter_templates

      def call # _chain_nested_filter
        filter_key_object.keys.each do |key|
          deep_chain([key], filter_key_object[key])
        end
      end

      private

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

      def find_like_key(keys)
        return nil unless like_semantics && like_semantics.keys.any?
        current_like_key = like_semantics
        keys.each do |key|
          current_like_key = current_like_key[key]
        end
        current_like_key
      end

      def find_i_like_key(keys)
        return nil unless i_like_semantics && i_like_semantics.keys.any?
        current_like_key = i_like_semantics
        keys.each do |key|
          current_like_key = current_like_key[key]
        end
        current_like_key
      end

      def _build_deep_chain(keys)
        name    = '' # prefix.to_s
        count   = keys.size - 1

        joins_before = []
        joins_after = []
        joins = ''
        where_before = []
        where_after = []
        out   = ''
        search_mode = nil
        type = nil
        leaf = nil

        if search_mode = find_like_key(keys)
          type = 'LIKE'
        elsif search_mode = find_i_like_key(keys)
          type = 'ILIKE'
        end
        leaf = keys.pop

        keys.each_with_index do |key, i|
          if keys.length == 1
            joins_before << ":#{key}"
          else
            if i == 0
              joins_before << "#{key}: "
            elsif (keys.length-1) == i
              joins_before << " :#{key}"
            else
              joins_before << "{ #{key}:"
              joins_after << " }"
            end
          end

          name += "#{key}#{infix}"
          where_before.push("{ #{key.to_s.pluralize}: ")
          where_after.push(" }")
        end

        joins = joins_before + joins_after

        name += "#{leaf}"
        where_middle = ["{ #{leaf}: #{prefix}#{name} }"]

        where = where_before + where_middle + where_after
        joins = joins.join
        where = where.join

        if search_mode
          query = build_like_query(
            type: type,
            query: '',
            filter: "#{prefix}#{name}",
            search_mode: search_mode,
            key: keys.last.to_s.pluralize,
            leaf: leaf
          )

          @filter_methods << "def #{prefix}filter#{infix}#{name};"\
            "@model.joins(#{joins}).#{query}; end;"

          @filter_templates << "@model = #{prefix}filter#{infix}#{name} if #{prefix}#{name};"
        else
          @filter_methods << "def #{prefix}filter#{infix}#{name};"\
            "@model.joins(#{joins}).where(#{where}); end;"

          @filter_templates << "@model = #{prefix}filter#{infix}#{name} if #{prefix}#{name};"
        end
      end

      def build_like_query(type:, query:, filter:, search_mode:, key:, leaf:)
        if db == :postgres
          query = "where(\"#{key}.#{leaf} #{type} ANY (ARRAY[?])\", "
          query += "prepare_terms(#{filter}, :#{search_mode}))"
        else
          query = "where(\"#{key}.#{leaf} #{type} :query\", "
          query += "query: \"%\#{#{filter}}%\")" if search_mode == :circumfix
          query += "query: \"%\#{#{filter}}\")" if search_mode == :prefix
          query += "query: \"\#{#{filter}}%\")" if search_mode == :suffix
        end

        query
      end

    end
  end
end

