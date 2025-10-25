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
        @filter_query = nil
      end
      attr_reader :keys, :prefix, :infix, :like_semantics, :i_like_semantics, :db, :filter_query
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

      def case_sensitive
        if db == :postgres
          'LIKE'
        elsif db == :mysql
          'LIKE BINARY'
        elsif db == :sqlserver
          'LIKE'
        else
          'LIKE'
        end
      end

      def case_insensitive
        if db == :postgres
          'ILIKE'
        elsif db == :mysql
          'LIKE'
        elsif db == :sqlserver
          'LIKE'
        else
          'LIKE'
        end
      end

      def _chain_filter_type(key)
        filter = "#{prefix}#{key}"
        query  = ''

        if like_semantics && mode = like_semantics[key]
          query = build_like_query(
            type: case_sensitive,
            query: query,
            filter: filter,
            mode: mode,
            key: key
          )
        elsif i_like_semantics && mode = i_like_semantics[key]
          query = build_like_query(
            type: case_insensitive,
            query: query,
            filter: filter,
            mode: mode,
            key: key
          )
        else
          query = "@model.where(#{key}: #{filter})"
        end

        @filter_query = query
      end

      # # @model.where('`authors`.`first_name` LIKE BINARY :query', query: "%teev%").or(@model.where('`authors`.`first_name` LIKE BINARY :query', query: "%imi%"))
      # if Array == filter
      #     first_term = filter.unshift
      #     query = "@model.where(\"#{key} #{type} ANY (ARRAY[?])\", "
      #     query += "prepare_terms(#{first_term}, :#{mode}))"
      #     filter.each { |term|
      #       query += ".or(@model.where(\"#{key} #{type} ANY (ARRAY[?])\", "
      #       query += "prepare_terms(#{first_term}, :#{mode})))"
      #     }
      # else
      #   query = "@model.where(\"#{key.to_s.split(".").map { |item| "`#{item}`" }.join(".")} #{type.to_s.upcase} :query\", "
      #   query += "query: prepare_terms(#{filter}, \"#{type.to_s.upcase}\", :#{search_mode}))"
      # end

      def build_like_query(type:, query:, filter:, mode:, key:)
        if db == :postgres
          query = "@model.where(\"#{key} #{type} ANY (ARRAY[?])\", "
          query += "prepare_terms(#{filter}, :#{mode}))"
        elsif db == :sqlserver
          # Delegate to helper that supports arrays and escaping with ESCAPE
          query = "sqlserver_like(@model, \"#{key}\", \"#{type}\", #{filter}, :#{mode})"
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

