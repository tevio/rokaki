# frozen_string_literal: true

# Standalone spec retained for ad‑hoc runs. It is disabled by default to avoid
# duplicate coverage with the shared examples that are included in each backend
# aware spec. Enable by setting RUN_STANDALONE_AUTO_DETECT=1.

if ENV['RUN_STANDALONE_AUTO_DETECT'] == '1'
  require 'spec_helper'
  require 'support/database_manager'

  RSpec.describe 'FilterModel backend auto-detection (standalone)' do
    context 'when only one adapter is in use (SQLite)' do
      # Set up a minimal SQLite schema + AR models
      before(:all) do
        @db_manager = DatabaseManager.new('sqlite')
        @db_manager.establish
        @db_manager.define_schema
        @db_manager.eval_record_layer

        # Seed a couple of records
        @ada = Author.create!(first_name: 'Ada', last_name: 'Lovelace')
        @article_1 = Article.create!(title: 'The First Article', content: 'Alpha', published: DateTime.now, author: @ada)
        @article_2 = Article.create!(title: 'Second', content: 'Beta', published: DateTime.now, author: @ada)
      end

      it 'uses the DSL without specifying db: (auto-detected from the model connection)' do
        klass = Class.new do
          include Rokaki::FilterModel

          filter_key_prefix :__
          filter_model :article # no db: specified; should auto-detect SQLite
          define_query_key :q

          filter_map do
            like title: :circumfix
          end

          attr_accessor :filters
          def initialize(filters: {})
            @filters = filters
          end
        end

        results = klass.new(filters: { q: 'First' }).results
        expect(results).to include(@article_1)
        expect(results).not_to include(@article_2)
      end
    end

    context 'when multiple adapters are detected and no explicit db is given' do
      it 'raises a Rokaki::Error asking the user to declare the backend' do
        klass = Class.new do
          include Rokaki::FilterModel

          filter_model :article # model provided, but detection will be forced to nil via overrides below
          define_query_key :q
        end

        # Force ambiguity: pretend model and global env cannot determine a single adapter
        class << klass
          # These shadow the class methods provided by the included module
          def detect_adapter_from_model(_model) = nil
          def adapters_in_use = [:postgres, :mysql]
        end

        expect do
          klass.class_eval do
            filter_map do
              like title: :circumfix
            end
          end
        end.to raise_error(Rokaki::Error, /Multiple database adapters detected/)
      end
    end

    context 'when no adapter can be determined at all' do
      it 'raises a Rokaki::Error instructing the user to pass db: explicitly' do
        klass = Class.new do
          include Rokaki::FilterModel

          filter_model :article
          define_query_key :q
        end

        # Force no detection paths to succeed
        class << klass
          def detect_adapter_from_model(_model) = nil
          def adapters_in_use = []
        end

        # Also ensure AR::Base fallback cannot detect anything
        allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(nil)

        expect do
          klass.class_eval do
            filter_map do
              like title: :circumfix
            end
          end
        end.to raise_error(Rokaki::Error, /Unable to auto-detect database adapter/)
      end
    end
  end
end
