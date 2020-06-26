# frozen_string_literal: true

require 'rokaki/version'
require 'rokaki/filterable'
require 'rokaki/filter_model'
require 'rokaki/filter_model/join_map'
require 'rokaki/filter_model/like_keys'
require 'rokaki/filter_model/basic_filter'
require 'rokaki/filter_model/nested_filter'
require 'rokaki/filter_model/nested_like_filters'

module Rokaki
  class Error < StandardError; end
end
