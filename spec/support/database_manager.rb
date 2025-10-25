require 'yaml'
require 'active_record'

class DatabaseManager
  def initialize(database)
    @database_config = YAML.load(File.read("./spec/support/databases/#{database}.yml"))
    # p @database_config
  end

  def establish
    if @database_config['adapter'] == 'sqlserver'
      begin
        require 'tiny_tds'
      rescue LoadError
        warn "tiny_tds gem not available; ensure it's in your bundle"
      end
      begin
        require 'activerecord-sqlserver-adapter'
      rescue LoadError
        warn "activerecord-sqlserver-adapter gem not available; ensure it's in your bundle"
      end
      # Always ensure target database exists by using master connection first
      dbname = @database_config['database']
      master_config = @database_config.merge('database' => 'master')
      ActiveRecord::Base.establish_connection(master_config)
      ActiveRecord::Base.connection.execute("IF DB_ID(N'#{dbname}') IS NULL CREATE DATABASE [#{dbname}]")
      # Now connect to target DB
      ActiveRecord::Base.establish_connection(@database_config)
      # Touch connection
      ActiveRecord::Base.connection
    else
      ActiveRecord::Base.establish_connection(@database_config)
    end
  end

  def define_schema
    ActiveRecord::Schema.define do
      create_table :authors, force: true do |t|
        t.string :first_name
        t.string :last_name
      end

      create_table :articles, force: true do |t|
        t.string :title
        t.string :content
        t.datetime :published
        t.belongs_to :author, index: true
      end

      create_table :reviews, force: true do |t|
        t.string :title
        t.string :content
        t.datetime :published
        t.belongs_to :article, index: true
      end
    end
  end

  def eval_record_layer
    eval(
      'module ::ActiveRecord
        module QueryMethods
          def structurally_incompatible_values_for_or(other)
            Relation::SINGLE_VALUE_METHODS.reject { |m| send("#{m}_value") == other.send("#{m}_value") } +
              (Relation::MULTI_VALUE_METHODS - [:joins, :eager_load, :references, :extending]).reject { |m| send("#{m}_values") == other.send("#{m}_values") } +
              (Relation::CLAUSE_METHODS - [:having, :where]).reject { |m| send("#{m}_clause") == other.send("#{m}_clause") }
          end
        end
      end

      # Define the models
      class ::Author < ::ActiveRecord::Base
        has_many :articles, inverse_of: :author
      end

      class ::Article < ::ActiveRecord::Base
        belongs_to :author, inverse_of: :articles, required: true
        has_many :reviews, inverse_of: :article
      end

      class ::Review < ::ActiveRecord::Base
        belongs_to :article, inverse_of: :reviews, required: true
      end
      '
    )
  end
end
