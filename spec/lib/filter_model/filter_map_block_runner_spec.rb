# frozen_string_literal: true
require 'spec_helper'
require_relative 'filter_model/filter_map_block_spec'

RSpec.describe 'FilterMap block DSL support' do
  include Rokaki

  # Using a dummy adapter symbol here; the shared example doesn't depend on DB
  include_examples "FilterModel::FilterMapBlockDSL", :dummy
end
