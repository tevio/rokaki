require_relative 'filter_model_spec'
require_relative 'model_filter_map_spec'
require_relative 'filter_model/basic_filter_spec'
require_relative 'filter_model/like_keys_spec'
require_relative 'filter_model/nested_filter_spec'
require_relative 'filter_model/filter_map_block_spec'

require 'support/database_manager'

RSpec.describe "Postgres" do
  db_manager = DatabaseManager.new("postgres")
  db_manager.establish
  db_manager.define_schema
  db_manager.eval_record_layer
  db = :postgres

  include_examples "FilterModel", db
  include_examples "FilterModel#filter_map", db
  include_examples "FilterModel::BasicFilter", db
  include_examples "FilterModel::NestedFilter", db
  include_examples "FilterModel::LikeKeys", db
  include_examples "FilterModel::FilterMapBlockDSL", db
end
