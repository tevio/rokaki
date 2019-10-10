# frozen_string_literal: true

module Rokaki
  module FilterModel
    module Like
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def like(args)
          raise ArgumentError, 'argument mush be a hash' unless args.is_a? Hash
          @_like_semantics = (@_like_semantics || {}).merge(args)
        end

        def _chain_filter_like_type(key)
          filter = "#{filter_key_prefix}#{key}"

          query = "@model.where(\"#{key} LIKE :query\", "
          if mode == :circumfix
            query += "query: \"%\#{#{filter}}%\")"
          end
          if mode == :infix
            query += "query: \"%\#{#{filter}}\")"
          end
          if mode == :suffix
            query += "query: \"\#{#{filter}}%\")"
          end
          "#{query};"
        end
      end
    end
  end
end
