# frozen_string_literal: true

module Rokaki
  module FilterModel
    class DeepAssignStruct
      def initialize(keys:, value:, struct: nil)
        @keys = keys
        @value = value
        @struct = struct
      end
      attr_reader :keys, :value
      attr_accessor :struct

      def call
        base_keys = keys
        i = base_keys.length - 1

        base_keys.reverse_each.reduce (value) do |struc,key|
          i -= 1
          cur_keys = base_keys[0..i]

          if struct
            val = struct.dig(*cur_keys)
            val[key] = struc
            p val
            return val
          else
            if key.is_a?(Integer)
              struct = [struc]
            else
              { key=>struc }
            end
          end
        end
      end

      private

      def deep_construct(keys, value)

        if keys.last.is_a?(Integer)
          rstruct = struct[keys.last] = value
        else
          rstruct = { keys.last => value }
        end

        keys[0..-2].reverse_each.reduce (rstruct) do |struc,key|
          if key.is_a?(Integer)
            [struc]
          else
            { key=>struc }
          end
        end
      end
    end
  end
end
