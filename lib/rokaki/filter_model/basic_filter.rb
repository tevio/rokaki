# frozen_string_literal: true

module Rokaki
  module FilterModel
    class BasicFilter
      def initialize(keys:, prefix:, infix:, like_semantics:, i_like_semantics:, db:, between_keys: nil, min_keys: nil, max_keys: nil)
        @keys = keys
        @prefix = prefix
        @infix = infix
        @like_semantics = like_semantics
        @i_like_semantics = i_like_semantics
        @db = db
        @between_keys = Array(between_keys).compact
        @min_keys = Array(min_keys).compact
        @max_keys = Array(max_keys).compact
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
        elsif db == :oracle
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
        elsif db == :oracle
          # Use 'ILIKE' as a signal; oracle_like will translate to UPPER(column) LIKE UPPER(:q)
          'ILIKE'
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
          # New preferred style: field => { between:/from:/to:/min:/max: }
          # Also accept direct Range/Array/Hash with from/to aliases.
          query = <<-RUBY
            begin
              _val = #{filter}
              if _val.is_a?(Hash)
                # Support wrapper keys like :between as well as bound aliases/min/max
                _inner = _val
                if _val.key?(:between) || _val.key?('between')
                  _inner = _val[:between] || _val['between']
                end
                _from = _inner[:from] || _inner['from'] || _inner[:since] || _inner['since'] || _inner[:after] || _inner['after'] || _inner[:start] || _inner['start'] || _inner[:min] || _inner['min']
                _to   = _inner[:to]   || _inner['to']   || _inner[:until] || _inner['until'] || _inner[:before] || _inner['before'] || _inner[:end]   || _inner['end']   || _inner[:max] || _inner['max']

                if _from.nil? && _to.nil?
                  # If hash contains range-like but with different container (e.g., { between: range })
                  if _inner.is_a?(Range)
                    _from = _inner.begin; _to = _inner.end
                  elsif _inner.is_a?(Array)
                    _from, _to = _inner[0], _inner[1]
                  end
                end

                # Adjust inclusive end-of-day behavior if upper bound appears to be a date or midnight time
                if !_to.nil? && (_to.is_a?(Date) && !_to.is_a?(DateTime) || (_to.respond_to?(:hour) && _to.hour == 0 && _to.min == 0 && _to.sec == 0))
                  _to = (_to.respond_to?(:to_time) ? _to.to_time : _to) + 86399
                end
                if !_from.nil? && !_to.nil?
                  @model.where("#{key} BETWEEN :from AND :to", from: _from, to: _to)
                elsif !_from.nil?
                  @model.where("#{key} >= :from", from: _from)
                elsif !_to.nil?
                  @model.where("#{key} <= :to", to: _to)
                else
                  # Inequality/nullability operators
                  _op_neq         = _val[:neq] || _val['neq']
                  _op_not_in      = _val[:not_in] || _val['not_in']
                  _op_is_null     = _val[:is_null] || _val['is_null']
                  _op_is_not_null = _val[:is_not_null] || _val['is_not_null']
                  _op_gt          = _val[:gt] || _val['gt']
                  _op_gte         = _val[:gte] || _val['gte']
                  _op_lt          = _val[:lt] || _val['lt']
                  _op_lte         = _val[:lte] || _val['lte']

                  if !_op_neq.nil?
                    @model.where("#{key} <> :v", v: _op_neq)
                  elsif _op_not_in
                    _arr = Array(_op_not_in)
                    return @model.none if _arr.empty?
                    @model.where("#{key} NOT IN (?)", _arr)
                  elsif _op_is_null == true
                    @model.where("#{key} IS NULL")
                  elsif _op_is_not_null == true || _op_is_null == false
                    @model.where("#{key} IS NOT NULL")
                  elsif !_op_gt.nil?
                    @model.where("#{key} > :v", v: _op_gt)
                  elsif !_op_gte.nil?
                    @model.where("#{key} >= :v", v: _op_gte)
                  elsif !_op_lt.nil?
                    @model.where("#{key} < :v", v: _op_lt)
                  elsif !_op_lte.nil?
                    @model.where("#{key} <= :v", v: _op_lte)
                  else
                    # Fall back to equality with the original hash
                    @model.where(#{key}: _val)
                  end
                end
              elsif _val.is_a?(Range)
                #{build_between_query(filter: filter, key: key)}
              else
                # Equality and IN semantics for arrays and scalars (Arrays are always IN lists)
                @model.where(#{key}: _val)
              end
            end
          RUBY
        end

        @filter_query = query
      end

      def build_between_query(filter:, key:)
        # Accept [from, to], Range, or {from:, to:}
        # Build appropriate where conditions with bound params
        <<-RUBY
          begin
            _val = #{filter}
            _from = _to = nil
            if _val.is_a?(Range)
              _from = _val.begin
              _to = _val.end
            elsif _val.is_a?(Array)
              _from, _to = _val[0], _val[1]
            elsif _val.is_a?(Hash)
              # allow aliases for from/to
              _from = _val[:from] || _val['from'] || _val[:since] || _val['since'] || _val[:after] || _val['after'] || _val[:start] || _val['start']
              _to   = _val[:to]   || _val['to']   || _val[:until] || _val['until'] || _val[:before] || _val['before'] || _val[:end]   || _val['end']
            else
              # single value → equality
              return @model.where(#{key}: _val)
            end

            if !_from.nil? && !_to.nil?
              @model.where("#{key} BETWEEN :from AND :to", from: _from, to: _to)
            elsif !_from.nil?
              @model.where("#{key} >= :from", from: _from)
            elsif !_to.nil?
              @model.where("#{key} <= :to", to: _to)
            else
              @model
            end
          end
        RUBY
      end

      def parse_range_semantics(key)
        k = key.to_s
        %w[_between _min _max _from _to _after _before _since _until _start _end].each do |suf|
          if k.end_with?(suf)
            base = k.sub(/#{Regexp.escape(suf)}\z/, '')
            op = case suf
                 when '_between' then :between
                 when '_min' then :min
                 when '_max' then :max
                 when '_from','_after','_since','_start' then :from
                 when '_to','_before','_until','_end' then :to
                 else nil
                 end
            return [base, op]
          end
        end
        [nil, nil]
      end

      def build_compare_query(op:, filter:, column:)
        operator = (op == :'>=') ? '>=' : '<='
        %Q{@model.where("#{column} #{operator} :v", v: #{filter})}
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
        elsif db == :oracle
          # Oracle helper handles case-insensitive via UPPER() when type is 'ILIKE'
          query = "oracle_like(@model, \"#{key}\", \"#{type}\", #{filter}, :#{mode})"
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

