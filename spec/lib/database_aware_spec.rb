require_relative 'filter_model_spec'
require_relative 'model_filter_map_spec'
require 'support/database_manager'

# RSpec.describe "Postgres" do
#   db_manager = DatabaseManager.new("postgres")
#   db_manager.establish
#   db_manager.define_schema
#   db_manager.eval_record_layer
#   include_examples "FilterModel", :postgres
#   # include_examples "FilterModel#filter_map", :postgres
# end

RSpec.describe "MySQL" do
  db_manager = DatabaseManager.new("mysql")
  db_manager.establish
  db_manager.define_schema
  db_manager.eval_record_layer
  include_examples "FilterModel", :mysql
  # include_examples "FilterModel#filter_map", :mysql
end
