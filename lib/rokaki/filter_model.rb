# frozen_string_literal: true

module Rokaki
  module FilterModel
    include Filterable
    def self.included(base)
      base.extend(ClassMethods)
    end

    def prepare_terms(param, mode)
      if Array === param
        return param.map { |term| "%#{term}%" } if mode == :circumfix
        return param.map { |term| "%#{term}" } if mode == :prefix
        return param.map { |term| "#{term}%" } if mode == :suffix
      else
        return ["%#{param}%"] if mode == :circumfix
        return ["%#{param}"] if mode == :prefix
        return ["#{param}%"] if mode == :suffix
      end
    end

    # Escape special LIKE characters in SQL Server patterns: %, _, [ and \\
    def escape_like(term)
      term.to_s.gsub(/[\\%_\[]/) { |m| "\\#{m}" }
    end

    # Build LIKE patterns with proper prefix/suffix/circumfix and escaping for SQL Server
    # Returns a String when param is scalar, or an Array of Strings when param is an Array
    def prepare_like_terms(param, mode)
      if Array === param
        case mode
        when :circumfix
          param.map { |t| "%#{escape_like(t)}%" }
        when :prefix
          param.map { |t| "%#{escape_like(t)}" }
        when :suffix
          param.map { |t| "#{escape_like(t)}%" }
        else
          param.map { |t| "%#{escape_like(t)}%" }
        end
      else
        case mode
        when :circumfix
          "%#{escape_like(param)}%"
        when :prefix
          "%#{escape_like(param)}"
        when :suffix
          "#{escape_like(param)}%"
        else
          "%#{escape_like(param)}%"
        end
      end
    end

    # Compose a SQL Server LIKE relation supporting arrays of terms (OR chained)
    # column should be a fully qualified column expression, e.g., "authors.first_name" or "cs.title"
    # type is usually "LIKE"
    def sqlserver_like(model, column, type, value, mode)
      terms = prepare_like_terms(value, mode)
      if terms.is_a?(Array)
        return model.none if terms.empty?
        rel = model.where("#{column} #{type} :q0 ESCAPE '\\'", q0: terms[0])
        terms[1..-1]&.each_with_index do |t, i|
          rel = rel.or(model.where("#{column} #{type} :q#{i + 1} ESCAPE '\\'", "q#{i + 1}".to_sym => t))
        end
        rel
      else
        model.where("#{column} #{type} :q ESCAPE '\\'", q: terms)
      end
    end

    # Compose an Oracle LIKE relation supporting arrays of terms and case-insensitive path via UPPER()
    # type_signal: 'LIKE' for case-sensitive semantics; 'ILIKE' to indicate case-insensitive (we will translate)
    def oracle_like(model, column, type_signal, value, mode)
      terms = prepare_like_terms(value, mode)
      ci = (type_signal.to_s.upcase == 'ILIKE')
      col_expr = ci ? "UPPER(#{column})" : column
      build_term = proc { |t| ci ? t.to_s.upcase : t }

      if terms.is_a?(Array)
        return model.none if terms.empty?
        first = build_term.call(terms[0])
        rel = model.where("#{col_expr} LIKE :q0 ESCAPE '\\'", q0: first)
        terms[1..-1]&.each_with_index do |t, i|
          rel = rel.or(model.where("#{col_expr} LIKE :q#{i + 1} ESCAPE '\\'", "q#{i + 1}".to_sym => build_term.call(t)))
        end
        rel
      else
        model.where("#{col_expr} LIKE :q ESCAPE '\\'", q: build_term.call(terms))
      end
    end

    # Compose a generic LIKE relation supporting arrays of terms (OR chained)
    # Used for adapters without special handling (e.g., SQLite)
    def generic_like(model, column, type, value, mode)
      terms = prepare_terms(value, mode)
      return model.none if terms.nil?
      if terms.is_a?(Array)
        return model.none if terms.empty?
        rel = model.where("#{column} #{type} :q0", q0: terms[0])
        terms[1..-1]&.each_with_index do |t, i|
          rel = rel.or(model.where("#{column} #{type} :q#{i + 1}", "q#{i + 1}".to_sym => t))
        end
        rel
      else
        # prepare_terms returns arrays for scalar input, so this branch is rarely used
        model.where("#{column} #{type} :q", q: terms)
      end
    end

    def prepare_regex_terms(param, mode)
      if Array === param
        param_map = param.map { |term| ".*#{term}.*" } if mode == :circumfix
        param_map = param.map { |term| ".*#{term}" } if mode == :prefix
        param_map = param.map { |term| "#{term}.*" } if mode == :suffix
        return param_map.join("|")
      else
        return [".*#{param}.*"] if mode == :circumfix
        return [".*#{param}"] if mode == :prefix
        return ["#{param}.*"] if mode == :suffix
      end
    end

    # "SELECT `articles`.* FROM `articles` INNER JOIN `authors` ON `authors`.`id` = `articles`.`author_id` WHERE (`authors`.`first_name` LIKE BINARY '%teev%' OR `authors`.`first_name` LIKE BINARY '%arv%')"
    def prepare_or_terms(param, type, mode)
      if Array === param
        param_map = param.map { |term| "%#{term}%" } if mode == :circumfix
        param_map = param.map { |term| "%#{term}" } if mode == :prefix
        param_map = param.map { |term| "#{term}%" } if mode == :suffix

        return param_map.join(" OR #{type} ")
      else
        return ["%#{param}%"] if mode == :circumfix
        return ["%#{param}"] if mode == :prefix
        return ["#{param}%"] if mode == :suffix
      end
    end


    module ClassMethods
      include Filterable::ClassMethods

      private

      def normalize_like_modes(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), h|
            h[k] = normalize_like_modes(v)
          end
        when Array
          obj.map { |e| normalize_like_modes(e) }
        when Symbol
          # Treat alternative affixes as circumfix
          return :circumfix if [:parafix, :confix, :ambifix].include?(obj)
          obj
        else
          obj
        end
      end

      # Merge two nested like/ilike mappings
      def deep_merge_like(a, b)
        return b if a.nil? || a == {}
        return a if b.nil? || b == {}
        a.merge(b) do |_, v1, v2|
          if v1.is_a?(Hash) && v2.is_a?(Hash)
            deep_merge_like(v1, v2)
          else
            # Prefer later definitions
            v2
          end
        end
      end

      # Wrap a normalized mapping with current nested context stack
      def wrap_in_context(mapping)
        return mapping if !@__ctx_stack || @__ctx_stack.empty?
        @__ctx_stack.reverse.inject(mapping) { |acc, key| { key => acc } }
      end

      # Block DSL: nested context for like/ilike within filter_map block
      def nested(name, &blk)
        if instance_variable_defined?(:@__in_filter_map_block) && @__in_filter_map_block
          raise ArgumentError, 'nested requires a symbol name' unless name.is_a?(Symbol)
          @__ctx_stack << name
          instance_eval(&blk) if blk
          @__ctx_stack.pop
        else
          raise NoMethodError, 'nested can only be used inside filter_map block'
        end
      end

      def filter_map(*args, &block)
        # Block form: requires prior calls to filter_model and define_query_key
        if block_given? && args.empty?
          raise ArgumentError, 'define_query_key must be called before block filter_map' unless @filter_map_query_key
          raise ArgumentError, 'filter_model must be called before block filter_map' unless @model
          @_filter_db ||= :postgres

          # Enter block-collection mode
          @__in_filter_map_block = true
          @__block_like_accumulator = {}
          @__block_ilike_accumulator = {}
          @__ctx_stack = []

          instance_eval(&block)

          # Exit and materialize definitions
          @__in_filter_map_block = false
          unless @__block_like_accumulator.empty?
            like(@__block_like_accumulator)
          end
          unless @__block_ilike_accumulator.empty?
            ilike(@__block_ilike_accumulator)
          end

          # cleanup
          @__block_like_accumulator = nil
          @__block_ilike_accumulator = nil
          @__ctx_stack = nil

          return
        end

        # Positional/legacy form
        model, query_key, options = args
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
        # In block form for FilterModel, allow equality filters inside nested contexts
        if instance_variable_defined?(:@__in_filter_map_block) && @__in_filter_map_block
          wrapped_keys = filter_keys.map { |fk| wrap_in_context(fk) }
          filter_keys = wrapped_keys
        end

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
          type: term_type,
          or_key: or_key
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

      def filter_db(db)
        @_filter_db = db
      end

      def filter_model(model_class, db: nil)
        @_filter_db = db if db
        @model = (model_class.is_a?(Class) ? model_class : Object.const_get(model_class.capitalize))
        class_eval "def set_model; @model ||= #{@model}; end;"
      end

      def case_sensitive
        if @_filter_db == :postgres
          'LIKE'
        elsif @_filter_db == :mysql
          # 'LIKE BINARY'
          'REGEXP'
        elsif @_filter_db == :sqlserver
          'LIKE'
        elsif @_filter_db == :oracle
          'LIKE'
        else
          'LIKE'
        end
      end

      def case_insensitive
        if @_filter_db == :postgres
          'ILIKE'
        elsif @_filter_db == :mysql
          # 'LIKE'
          'REGEXP'
        elsif @_filter_db == :sqlserver
          'LIKE'
        elsif @_filter_db == :oracle
          # Use 'ILIKE' as a signal for case-insensitive; oracle_like will translate to UPPER(column) LIKE UPPER(:q)
          'ILIKE'
        else
          'LIKE'
        end
      end

      def like(args)
        raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash
        if instance_variable_defined?(:@__in_filter_map_block) && @__in_filter_map_block
          normalized = normalize_like_modes(args)
          @__block_like_accumulator = deep_merge_like(@__block_like_accumulator, wrap_in_context(normalized))
          return
        end

        normalized = normalize_like_modes(args)
        @_like_semantics = (@_like_semantics || {}).merge(normalized)

        like_keys = LikeKeys.new(normalized)
        like_filters(like_keys, term_type: case_sensitive)
      end

      def ilike(args)
        raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash
        if instance_variable_defined?(:@__in_filter_map_block) && @__in_filter_map_block
          normalized = normalize_like_modes(args)
          @__block_ilike_accumulator = deep_merge_like(@__block_ilike_accumulator, wrap_in_context(normalized))
          return
        end

        normalized = normalize_like_modes(args)
        @i_like_semantics = (@i_like_semantics || {}).merge(normalized)

        like_keys = LikeKeys.new(normalized)
        like_filters(like_keys, term_type: case_insensitive)
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
