require 'yaml'
require 'active_record'

class DatabaseManager
  def initialize(database)
    @database_config = YAML.load(File.read("./spec/support/databases/#{database}.yml"))
    # Allow environment overrides to avoid hardcoding ports/hosts across adapters
    case @database_config['adapter']
    when 'sqlserver'
      @database_config['host'] = ENV['SQLSERVER_HOST'] if ENV['SQLSERVER_HOST']
      @database_config['port'] = ENV['SQLSERVER_PORT'].to_i if ENV['SQLSERVER_PORT']
      @database_config['username'] = ENV['SQLSERVER_USERNAME'] if ENV['SQLSERVER_USERNAME']
      @database_config['password'] = ENV['SQLSERVER_PASSWORD'] if ENV['SQLSERVER_PASSWORD']
      @database_config['database'] = ENV['SQLSERVER_DATABASE'] if ENV['SQLSERVER_DATABASE']
    when 'mysql2'
      @database_config['host'] = ENV['MYSQL_HOST'] if ENV['MYSQL_HOST']
      @database_config['port'] = ENV['MYSQL_PORT'].to_i if ENV['MYSQL_PORT']
      @database_config['username'] = ENV['MYSQL_USERNAME'] if ENV['MYSQL_USERNAME']
      @database_config['password'] = ENV['MYSQL_PASSWORD'] if ENV['MYSQL_PASSWORD']
      @database_config['database'] = ENV['MYSQL_DATABASE'] if ENV['MYSQL_DATABASE']
    when 'postgresql'
      @database_config['host'] = ENV['POSTGRES_HOST'] if ENV['POSTGRES_HOST']
      @database_config['port'] = ENV['POSTGRES_PORT'].to_i if ENV['POSTGRES_PORT']
      @database_config['username'] = ENV['POSTGRES_USERNAME'] if ENV['POSTGRES_USERNAME']
      @database_config['password'] = ENV['POSTGRES_PASSWORD'] if ENV['POSTGRES_PASSWORD']
      @database_config['database'] = ENV['POSTGRES_DATABASE'] if ENV['POSTGRES_DATABASE']
    when 'oracle_enhanced'
      # Oracle ENV overrides (service name or database/tns alias)
      @database_config['host'] = ENV['ORACLE_HOST'] if ENV['ORACLE_HOST']
      @database_config['port'] = ENV['ORACLE_PORT'].to_i if ENV['ORACLE_PORT']
      @database_config['username'] = ENV['ORACLE_USERNAME'] if ENV['ORACLE_USERNAME']
      @database_config['password'] = ENV['ORACLE_PASSWORD'] if ENV['ORACLE_PASSWORD']
      @database_config['database'] = ENV['ORACLE_DATABASE'] if ENV['ORACLE_DATABASE']
      @database_config['service_name'] = ENV['ORACLE_SERVICE_NAME'] if ENV['ORACLE_SERVICE_NAME']
    when 'sqlite3'
      # SQLite ENV override; default to in-memory for tests
      @database_config['database'] = ENV['SQLITE_DATABASE'] if ENV['SQLITE_DATABASE']
    end
    # p @database_config
  end

  def establish
    case @database_config['adapter']
    when 'sqlserver'
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
      ActiveRecord::Base.establish_connection(@database_config)
      ActiveRecord::Base.connection # touch
    when 'oracle_enhanced'
      begin
        # ruby-oci8 is required via 'oci8'
        require 'oci8'
      rescue LoadError
        warn "ruby-oci8 gem not available; ensure it's in your bundle"
      end
      begin
        require 'active_record/connection_adapters/oracle_enhanced_adapter'
      rescue LoadError
        warn "activerecord-oracle_enhanced-adapter gem not available; ensure it's in your bundle"
      end
      # Build a proper Oracle connection string if only service_name is provided
      db = @database_config
      if db['database'].nil? && db['service_name']
        host = db['host'] || 'localhost'
        port = db['port'] || 1521
        service = (db['service_name'] || '').to_s
        # Prefer a full descriptor to avoid EZCONNECT quirks and service registration edge cases
        db['database'] = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=#{host})(PORT=#{port}))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=#{service.downcase})))"
      end
      # Set a sane default to avoid US7ASCII fallback warnings
      ENV['NLS_LANG'] ||= 'AL32UTF8'
      # For Oracle we assume the user/schema exists and we create tables in the current schema
      ActiveRecord::Base.establish_connection(@database_config)
      ActiveRecord::Base.connection # touch
    when 'postgresql'
      # Ensure database exists by connecting to default 'postgres' DB
      dbname = @database_config['database']
      bootstrap = @database_config.merge('database' => 'postgres')
      ActiveRecord::Base.establish_connection(bootstrap)
      exists = ActiveRecord::Base.connection.exec_query("SELECT 1 FROM pg_database WHERE datname='#{dbname}'").any?
      unless exists
        ActiveRecord::Base.connection.execute("CREATE DATABASE \"#{dbname}\"")
      end
      ActiveRecord::Base.establish_connection(@database_config)
      ActiveRecord::Base.connection # touch
    when 'mysql2'
      # Ensure database exists by connecting without specifying database
      dbname = @database_config['database']
      bootstrap = @database_config.dup
      bootstrap.delete('database')
      ActiveRecord::Base.establish_connection(bootstrap)
      ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS `#{dbname}`")
      ActiveRecord::Base.establish_connection(@database_config)
      ActiveRecord::Base.connection # touch
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
