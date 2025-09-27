require 'pg'
require 'active_record'
require 'database_cleaner/active_record'

DatabaseCleaner.strategy = :truncation

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

# Connect to a postgres database
#
# createdb rokaki
# createuser rokaki

# ActiveRecord::Base.establish_connection(
#   :adapter  => "postgresql",
#   :host     => "localhost",
#   :username => "rokaki",
#   :password => "rokaki",
#   :database => "rokaki"
# )

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "127.0.0.1",
  :port     => "3306",
  :username => "rokaki",
  :password => "rokaki",
  :database => "rokaki"
)

# Define a minimal database schema
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

module ActiveRecord
  module QueryMethods
    def structurally_incompatible_values_for_or(other)
      Relation::SINGLE_VALUE_METHODS.reject { |m| send("#{m}_value") == other.send("#{m}_value") } +
        (Relation::MULTI_VALUE_METHODS - [:joins, :eager_load, :references, :extending]).reject { |m| send("#{m}_values") == other.send("#{m}_values") } +
        (Relation::CLAUSE_METHODS - [:having, :where]).reject { |m| send("#{m}_clause") == other.send("#{m}_clause") }
    end
  end
end

# Define the models
class Author < ActiveRecord::Base
  has_many :articles, inverse_of: :author
end

class Article < ActiveRecord::Base
  belongs_to :author, inverse_of: :articles, required: true
  has_many :reviews, inverse_of: :article
end

class Review < ActiveRecord::Base
  belongs_to :article, inverse_of: :reviews, required: true
end
