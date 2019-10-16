# frozen_string_literal: true

module Rokaki
  module FilterModel
    class LikeKeys
      def initialize(args)
        @args = args
        @like_keys = []
      end

      attr_reader :args, :like_keys

      def call
        args.keys.each do |key|
          like_keys << map_keys(args[key], key)
        end
        like_keys
      end

      private

      def map_keys(value, key)
        key_result = {}

        if value.is_a? Hash
        value.keys.each do |sub_key|
          sub_value = value[sub_key]

          if sub_value.is_a? Symbol
            if key_result[key].is_a? Array
              key_result[key] << sub_key
            else
              key_result[key] = [ sub_key ]
            end

          elsif sub_value.is_a? Hash
            key_result[key] = map_keys(sub_value, sub_key)
          end
        end
        else
          key_result = key
        end

        key_result
      end
    end
  end
end
