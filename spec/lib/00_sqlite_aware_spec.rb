ENV['DB_AWARE'] = 'true'
require_relative 'filter_model_spec'
require_relative 'model_filter_map_spec'
require_relative 'filter_model/basic_filter_spec'
require_relative 'filter_model/like_keys_spec'
require_relative 'filter_model/nested_filter_spec'
require_relative 'filter_model/filter_map_block_spec'
require_relative 'filter_model/affix_synonyms_spec'
require_relative 'dynamic_listener_spec'
require_relative 'filterable_block_spec'
require_relative 'auto_detect_backend_shared_examples'
require_relative 'filter_model/range_filters_shared_examples'
require_relative 'filter_model/inequality_filters_shared_examples'

require 'support/database_manager'

RSpec.describe "SQLite" do
  db_manager = DatabaseManager.new("sqlite")
  db_manager.establish
  db_manager.define_schema
  db_manager.eval_record_layer
  db = :sqlite

  include_examples "FilterModel", db
  include_examples "FilterModel#filter_map", db
  include_examples "FilterModel::BasicFilter", db
  include_examples "FilterModel::NestedFilter", db
  include_examples "FilterModel::LikeKeys", db
  include_examples "FilterModel::FilterMapBlockDSL", db
  include_examples "FilterModel::AffixSynonyms", db
  include_examples "AutoDetectBackend", db
  include_examples "FilterModel::RangeFilters", db
  include_examples "FilterModel::NestedRangeFilters", db
  # Also run the Filterable block DSL shared examples (DB-agnostic)
  include_examples "Filterable::FilterMapBlockDSL"
end
