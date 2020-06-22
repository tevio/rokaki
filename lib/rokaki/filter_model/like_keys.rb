# frozen_string_literal: true

module Rokaki
  module FilterModel
    # Converts deep hashes into keys
    # effectively drops the leaf values and make's their
    # keys the leaves
    #
    class LikeKeys
      def initialize(args)
        @args = args
        @like_keys = []
      end

      attr_reader :args, :like_keys

      def call
        args.keys.each do |key|
          map_keys(args[key], key)
        end
        like_keys
      end

      private

      def map_keys(value, key, key_path = [])
        key_result = {}
        key_path << key

        if value.is_a? Hash
        value.keys.each do |sub_key|
          sub_value = value[sub_key]

          if sub_value.is_a? Symbol
            if key_result[key].is_a? Array
              key_result[key] << sub_key
            else
              key_result[key] = [ sub_key ]
              @like_keys << deep_assign(key_path, key_result[key])
            end

          elsif sub_value.is_a? Hash
            map_keys(sub_value, sub_key, key_path)
          end
        end
        else
          @like_keys = [key]
        end

        key_result
      end

      # Many thanks Cary Swoveland
      # https://stackoverflow.com/questions/56634950/ruby-dig-set-assign-values-using-hashdig/56635124
      #
      def deep_assign(keys, value)
        keys[0..-2].reverse_each.reduce ({ keys.last => value }) { |h,key| { key=>h } }
      end
    end
  end
end
