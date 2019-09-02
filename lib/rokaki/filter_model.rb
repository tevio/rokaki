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
        @_chain_filters << "@model = @model.where(#{key.to_s}: #{key.to_s}) if #{key.to_s};"
      end

      def _build_deep_chain(keys)
        name    = @filter_key_prefix.to_s
        count   = keys.size - 1

        joins = ""
        where = ""
        out   = ""

        leaf = keys.pop

        keys.each_with_index do |key, i|
          if keys.length == 1
            name  = "#{key}#{filter_key_infix.to_s}#{leaf}"
            joins = ":#{key}"

            where = "{ #{key.to_s.pluralize}: { #{leaf}: #{name} } }"
          end
        end

        # keys.each_with_index do |key, i|
        #   name += key.to_s
        #   name += filter_key_infix.to_s unless count == i

        #   joins += "{ #{key.to_s}: " unless count == i
        #   where += "{ #{key.to_s.pluralize}: " unless count == i
        #   out += " }" unless count == i

        #   joins += key.to_s if count == i
        #   where += name if count == i
        # end

        joins = joins += out
        where = where += out

        @_chain_filters << "@model = @model.joins(#{joins}).where(#{where}) if #{name};"
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

      def like(*args)

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
        results_def = "def results;"
        @_chain_filters.each do |item|
          results_def += item
        end
        results_def += '@model;end;'
        class_eval results_def
      end
    end
  end
end
