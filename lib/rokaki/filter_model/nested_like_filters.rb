# frozen_string_literal: true
require 'active_support/inflector'

module Rokaki
  module FilterModel
    class NestedLikeFilters
      def initialize(filter_key_object:, prefix:, infix:, db:, mode: :and, or_key: :or, type: :like)
        @filter_key_object = filter_key_object
        @prefix = prefix
        @infix = infix
        @db = db
        @mode = mode
        @or_key = or_key
        @type = type

        @names = []
        @filter_methods = []
        @templates = []
        @filter_queries = []
        @method_names = []
        @filter_names = []
        @join_key_paths = []
        @key_paths = []
        @search_modes = []
        @modes = []
      end
      attr_reader :filter_key_object, :prefix, :infix, :like_semantics, :i_like_semantics,
        :db, :mode, :or_key, :filter_queries, :type
      attr_accessor :filter_methods, :templates, :method_names, :filter_names, :names, :join_key_paths, :key_paths, :search_modes, :modes

      def call
        build_filters_data
        compound_filters
      end

      def build_filters_data
        results = filter_key_object.key_paths.each do |key_path|
          if key_path.is_a?(Symbol)
            build_filter_data(key_path)
          else
            if key_path.include? or_key
              build_filter_data(key_path.dup, mode: or_key)
            else
              build_filter_data(key_path.dup)
            end
          end
        end
      end

      def compound_filters
        # key_paths represents a structure like
        # [
        #   [ # this is an or
        #     [:articles, :title],
        #     [:articles, :authors, :first_name],
        #     [:articles, :authors, :reviews, :title],
        #     [:articles, :authors, :reviews, :content]
        #   ],
        #   [:articles, :content] # this is an and
        # ]
        #
        # Each item in the array represents a compounded filter
        #
        key_paths.each_with_index do |key_path_item, index|
          base_names = get_name(index)
          join_map = JoinMap.new(join_key_paths[index])
          join_map.call

          if key_path_item.first.is_a?(Array)
            item_search_modes = search_modes[index]

            base_name = base_names.shift
            method_name = prefix.to_s + ([:filter].push base_name).compact.join(infix.to_s)
            method_name += (infix.to_s+'or'+infix.to_s) + (base_names).join(infix.to_s+'or'+infix.to_s)
            item_filter_names = [prefix.to_s + base_name]

            base_names.each do |filter_base_name|
              item_filter_names << (prefix.to_s + filter_base_name)
            end

            base_modes = modes[index]
            key_path_item.each_with_index do |key_path, kp_index|

              build_query(keys: key_path.dup, join_map: join_map.result, mode: base_modes[kp_index], filter_name: item_filter_names[kp_index], search_mode: item_search_modes[kp_index])
            end

            item_filter_queries = filter_queries[index]
            first_query = item_filter_queries.shift

            ored = item_filter_queries.map do |query|
              ".or(#{query})"
            end

            filter_conditions = item_filter_names.join(' || ')

            @filter_methods << "def #{method_name}; #{first_query + ored.join}; end;"
            @templates << "@model = #{method_name} if #{filter_conditions};"
          else

            base_name = get_name(index)
            filter_name = "#{prefix}#{get_filter_name(index)}"

            method_name = ([prefix, :filter, base_name]).compact.join(infix.to_s)

            build_query(keys: key_path_item.dup, join_map: join_map.result, filter_name: filter_name, search_mode: search_modes[index])

            @filter_methods << "def #{method_name}; #{filter_queries[index]}; end;"
            @templates << "@model = #{method_name} if #{filter_name};"
          end
        end
      end

      private

      def get_name(index)
        names[index]
      end

      def get_filter_name(index)
        filter_names[index]
      end

      def find_mode_key(keys)
        current_like_key = @filter_key_object.args.dup
        keys.each do |key|
          current_like_key = current_like_key[key]
        end
        current_like_key
      end

      def build_filter_data(key_path, mode: :and)
        # if key_path.is_a?(Symbol)
        #   search_mode = @filter_key_object.args[key_path]

        #   name = key_path
        #   filter_name = (prefix.to_s + key_path.to_s)
        #   @names << name
        #   @filter_names << filter_name
        #   @key_paths << key_path
        #   @search_modes << search_mode
        #   @modes << mode
        # else
          search_mode = find_mode_key(key_path)

          key_path.delete(mode)

          name = key_path.join(infix.to_s)
          filter_name = key_path.compact.join(infix.to_s)

          if mode == or_key
            @names << [@names.pop, name].flatten
            @filter_names << [@filter_names.pop, filter_name].flatten

            or_key_paths = @key_paths.pop
            if or_key_paths.first.is_a?(Array)
              @key_paths <<  [*or_key_paths] + [key_path.dup]
            else
              @key_paths <<  [or_key_paths] + [key_path.dup]
            end

            @search_modes << [@search_modes.pop, search_mode].flatten
            @modes << [@modes.pop, mode].flatten

          else
            @names << name
            @filter_names << filter_name
            @key_paths << key_path.dup # having this wrapped in an array is messy for single items
            @search_modes << search_mode
            @modes << mode
          end

          join_key_path = key_path.dup

          leaf = join_key_path.pop
          if mode == or_key
            or_join_key_paths = @join_key_paths.pop
            if or_join_key_paths.first.is_a?(Array)
              @join_key_paths <<  [*or_join_key_paths] + [join_key_path.dup]
            else
              @join_key_paths <<  [or_join_key_paths] + [join_key_path.dup]
            end
          else
            if join_key_path.length == 1
              @join_key_paths << join_key_path
            else
              @join_key_paths << [join_key_path.dup]
            end
          end
        # end
      end

      # DOUBLE SPLAT HASHES TO MAKE ARG LISTS!
      def build_query(keys: , join_map:, mode: :and, filter_name:, search_mode:)
        leaf = nil
        leaf = keys.pop


        query = build_like_query(
          type: type,
          query: '',
          filter: filter_name,
          search_mode: search_mode,
          key: keys.last,
          leaf: leaf
        )

        if join_map.empty?
          filter_query = "@model.#{query}"
        elsif join_map.is_a?(Array)
          filter_query = "@model.joins(*#{join_map}).#{query}"
        else
          filter_query = "@model.joins(**#{join_map}).#{query}"
        end

        if mode == or_key
          @filter_queries << [@filter_queries.pop, filter_query].flatten
        else
          @filter_queries << filter_query
        end
        filter_query
      end

      def build_like_query(type:, query:, filter:, search_mode:, key:, leaf:)
        key_leaf = key ? "#{key.to_s.pluralize}.#{leaf}" : leaf
        if db == :postgres
          query = "where(\"#{key_leaf} #{type.to_s.upcase} ANY (ARRAY[?])\", "
          query += "prepare_terms(#{filter}, :#{search_mode}))"
        else
          query = "where(\"#{key_leaf} #{type.to_s.upcase} :query\", "
          query += "query: \"%\#{#{filter}}%\")" if search_mode == :circumfix
          query += "query: \"%\#{#{filter}}\")" if search_mode == :prefix
          query += "query: \"\#{#{filter}}%\")" if search_mode == :suffix
        end

        query
      end

    end
  end
end

