# frozen_string_literal: true

# DOUBLE SPLAT HASHES TO MAKE ARG LISTS!
#
# Array#dig could be useful
#
# Array#intersection could be useful
#
# Array#difference could be useful
#

module Rokaki
  module FilterModel
    class JoinMap
      def initialize(key_paths)
        @key_paths = key_paths
        @result = {}
      end

      attr_reader :key_paths
      attr_accessor :result

      def call
        key_paths.uniq.each do |key_path|
          current_key_path = []
          previous_key = nil

          if Symbol === key_path
            if key_paths.length == 1
              @result = key_paths
            else
              result[key_path] = {} unless result.keys.include? key_path
            end
          end

          if Array === key_path
            key_path.each do |key|
              current_path_length = current_key_path.length

              if current_path_length > 0 && result.dig(current_key_path).nil?

                if current_path_length == 1
                  parent_result = result[previous_key]

                  if Symbol === parent_result && parent_result != key
                    result[previous_key] = [parent_result, key]
                  elsif Array === parent_result

                    parent_result.each_with_index do |array_item, index|
                      if array_item == key
                        current_key_path << index
                      end
                    end

                  else
                    result[previous_key] = key unless result[previous_key] == key
                  end

                else
                  previous_key_path = current_key_path - [previous_key]
                  previous_path_length = previous_key_path.length
                  p current_key_path

                  if previous_path_length == 1
                    res = result.dig(*previous_key_path)

                    if Symbol === res
                      result[previous_key_path.first] = { previous_key => key }
                    end
                  elsif previous_path_length > 1
                    res = result.dig(*previous_key_path)

                    if Symbol === res
                      base = previous_key_path.pop
                      result.dig(*previous_key_path)[base] = { previous_key => key }
                    end
                  end

                end
              else
              end

              previous_key = key
              current_key_path << key
            end
          end
        end
        result
      end
    end
  end
end













