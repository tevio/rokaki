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

      def _build_deep_chain(keys)
        name    = ''
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
          type = case_sensitive
        elsif search_mode = find_i_like_key(keys)
          type = case_insensitive
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

        joins_arr = joins_before + joins_after
        joins_str = joins_arr.join

        name += "#{leaf}"

        if search_mode
          if db == :sqlserver || db == :oracle
            key_leaf = "#{keys.last.to_s.pluralize}.#{leaf}"
            helper = db == :sqlserver ? 'sqlserver_like' : 'oracle_like'
            @filter_methods << "def #{prefix}filter#{infix}#{name};"\
              "#{helper}(@model.joins(#{joins_str}), \"#{key_leaf}\", \"#{type}\", #{prefix}#{name}, :#{search_mode}); end;"

            @filter_templates << "@model = #{prefix}filter#{infix}#{name} if #{prefix}#{name};"
          else
            query = build_like_query(
              type: type,
              query: '',
              filter: "#{prefix}#{name}",
              search_mode: search_mode,
              key: keys.last.to_s.pluralize,
              leaf: leaf
            )

            @filter_methods << "def #{prefix}filter#{infix}#{name};"\
              "@model.joins(#{joins_str}).#{query}; end;"

            @filter_templates << "@model = #{prefix}filter#{infix}#{name} if #{prefix}#{name};"
          end
        else
          # Preferred: value Hash with sub-keys between/from/to/min/max; also accept Range/Array directly
          qualified_col = "#{keys.last.to_s.pluralize}.#{leaf}"
          body = <<-RUBY
            @model.joins(#{joins_str}).instance_eval do
              _val = #{prefix}#{name}
              if _val.is_a?(Hash)
                _inner = _val
                if _val.key?(:between) || _val.key?('between')
                  _inner = _val[:between] || _val['between']
                end
                _from = _inner[:from] || _inner['from'] || _inner[:since] || _inner['since'] || _inner[:after] || _inner['after'] || _inner[:start] || _inner['start'] || _inner[:min] || _inner['min']
                _to   = _inner[:to]   || _inner['to']   || _inner[:until] || _inner['until'] || _inner[:before] || _inner['before'] || _inner[:end]   || _inner['end']   || _inner[:max] || _inner['max']
                if _from.nil? && _to.nil?
                  if _inner.is_a?(Range)
                    _from = _inner.begin; _to = _inner.end
                  elsif _inner.is_a?(Array)
                    _from, _to = _inner[0], _inner[1]
                  end
                end
                if !_from.nil? && !_to.nil?
                  where("#{qualified_col} BETWEEN :from AND :to", from: _from, to: _to)
                elsif !_from.nil?
                  where("#{qualified_col} >= :from", from: _from)
                elsif !_to.nil?
                  where("#{qualified_col} <= :to", to: _to)
                else
                  where("#{qualified_col} = :v", v: _val)
                end
              elsif _val.is_a?(Range)
                where("#{qualified_col} BETWEEN :from AND :to", from: _val.begin, to: _val.end)
              elsif _val.is_a?(Array)
                _from, _to = _val[0], _val[1]
                if !_from.nil? && !_to.nil?
                  where("#{qualified_col} BETWEEN :from AND :to", from: _from, to: _to)
                elsif !_from.nil?
                  where("#{qualified_col} >= :from", from: _from)
                elsif !_to.nil?
                  where("#{qualified_col} <= :to", to: _to)
                else
                  self
                end
              else
                where("#{qualified_col} = :v", v: _val)
              end
            end
          RUBY
          @filter_methods << "def #{prefix}filter#{infix}#{name};#{body}; end;"
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
        end

        query
      end

      def parse_range_semantics(key)
        k = key.to_s
        %w[_between _min _max _from _to _after _before _since _until _start _end].each do |suf|
          if k.end_with?(suf)
            base = k.sub(/#{Regexp.escape(suf)}\z/, '')
            op = case suf
                 when '_between' then :between
                 when '_min' then :from   # min → lower bound
                 when '_max' then :to     # max → upper bound
                 when '_from','_after','_since','_start' then :from
                 when '_to','_before','_until','_end' then :to
                 else nil
                 end
            return [base, op]
          end
        end
        [nil, nil]
      end

    end
  end
end

