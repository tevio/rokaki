require_relative 'filter_model_spec'
require_relative 'model_filter_map_spec'
require_relative 'filter_model/basic_filter_spec'
require_relative 'filter_model/like_keys_spec'
require_relative 'filter_model/nested_filter_spec'

require 'support/database_manager'

RSpec.describe "MySQL" do
  db_manager = DatabaseManager.new("mysql")
  db_manager.establish
  db_manager.define_schema
  db_manager.eval_record_layer
  db = :mysql

  include_examples "FilterModel", db
  include_examples "FilterModel#filter_map", db
  include_examples "FilterModel::BasicFilter", db
  include_examples "FilterModel::NestedFilter", db
  include_examples "FilterModel::LikeKeys", db
end
