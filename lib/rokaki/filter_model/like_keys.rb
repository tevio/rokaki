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
        @keys = []
        @key_paths = []
      end

      attr_reader :args, :keys, :key_paths

      def call
        args.keys.each do |key|
          map_keys(key: key, value: args[key])
        end
        keys
      end

      private

      def map_keys(key:, value:, key_path: [])

        if value.is_a?(Hash)
          key_path << key
          value.keys.each do |key|
            map_keys(key: key, value: value[key], key_path: key_path.dup)
          end
        end

        if value.is_a?(Symbol)
          keys << (key_path.empty? ? key : deep_assign(key_path, key))
          key_path << key
          key_paths << key_path
        end

        key_path

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
