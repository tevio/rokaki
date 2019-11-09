# frozen_string_literal: true

module Rokaki
  module FilterModel
    class BasicFilter
      def initialize(keys:, prefix:, infix:, like_semantics:, i_like_semantics:, db:)
        @keys = keys
        @prefix = prefix
        @infix = infix
        @like_semantics = like_semantics
        @i_like_semantics = i_like_semantics
        @db = db
      end
      attr_reader :keys, :prefix, :infix, :like_semantics, :i_like_semantics, :db
      attr_accessor :filter_method, :filter_template

      def call
        first_key = keys.shift
        filter = "#{prefix}#{first_key}"
        name = first_key

        keys.each do |key|
          filter += "#{infix}#{key}"
          name += "#{infix}#{key}"
        end

        @filter_method = "def #{prefix}filter_#{name};" \
          "#{_chain_filter_type(name)} end;"

        # class_eval filter_method, __FILE__, __LINE__ - 2

        @filter_template = "@model = #{prefix}filter_#{name} if #{filter};"
      end

      def _chain_filter_type(key)
        filter = "#{prefix}#{key}"
        query  = ''

        if like_semantics && mode = like_semantics[key]
          query = build_like_query(
            type: 'LIKE',
            query: query,
            filter: filter,
            mode: mode,
            key: key
          )
        elsif i_like_semantics && mode = i_like_semantics[key]
          query = build_like_query(
            type: 'ILIKE',
            query: query,
            filter: filter,
            mode: mode,
            key: key
          )
        else
          query = "@model.where(#{key}: #{filter})"
        end

        query
      end

      def build_like_query(type:, query:, filter:, mode:, key:)
        if db == :postgres
          query = "@model.where(\"#{key} #{type} ANY (ARRAY[?])\", "
          query += "prepare_terms(#{filter}, :#{mode}))"
        else
          query = "@model.where(\"#{key} #{type} :query\", "
          query += "query: \"%\#{#{filter}}%\")" if mode == :circumfix
          query += "query: \"%\#{#{filter}}\")" if mode == :prefix
          query += "query: \"\#{#{filter}}%\")" if mode == :suffix
        end

        query
      end
    end
  end
end

