require_relative 'filter_model_spec'
require_relative 'model_filter_map_spec'
require_relative 'filter_model/basic_filter_spec'
require_relative 'filter_model/like_keys_spec'
require_relative 'filter_model/nested_filter_spec'

require 'support/database_manager'

RSpec.describe "Postgres" do
  db_manager = DatabaseManager.new("postgres")
  db_manager.establish
  db_manager.define_schema
  db_manager.eval_record_layer

  include_examples "FilterModel", :postgres
  include_examples "FilterModel#filter_map", :postgres
  include_examples "FilterModel::BasicFilter", :postgres
  include_examples "FilterModel::NestedFilter", :postgres
  include_examples "FilterModel::LikeKeys", :postgres
end

# RSpec.describe "MySQL" do
#   db_manager = DatabaseManager.new("mysql")
#   db_manager.establish
#   db_manager.define_schema
#   db_manager.eval_record_layer
#   include_examples "FilterModel", :mysql
#   include_examples "FilterModel#filter_map", :mysql
# end
