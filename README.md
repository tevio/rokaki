# Rokaki

[![Gem Version](https://badge.fury.io/rb/rokaki.svg)](https://badge.fury.io/rb/rokaki)
[![Run RSpec tests](https://github.com/tevio/rokaki/actions/workflows/spec.yml/badge.svg)](https://github.com/tevio/rokaki/actions/workflows/spec.yml)

This gem was written to dry up filtering services in ActiveRecord based Rails apps or any plain Ruby app looking to implement "filters" or "faceted" search.

The overall vision is to abstract away all of the lower level repetitive SQL and relational code to allow you to write model filters in a simple, relatively intuitive way, using ruby hashes and arrays mostly.

The DSL allows you to construct complex search models to filter results through without writing any SQL. I would recommend the reader to consult the specs in order to understand the features and syntax in detail, an intermediate understanding of Ruby and rspec TDD, and basic relational logic are recommended.

There are two modes of use, `Filterable` (designed for plain Ruby) and `FilterModel` (designed for Rails) that can be activated through the use of two mixins respectively, `include Rokaki::Filterable` or `include Rokaki::FilterModel`.
## Installation

Add this line to your application's Gemfile:

You can install from Rubygems:
```
gem 'rokaki'
```
Or from github

```ruby
gem 'rokaki', git: 'https://github.com/tevio/rokaki.git'
```

And then execute:

    $ bundle

## `Rokaki::Filterable` - Usage

To use the DSL first include the `Rokaki::Filterable` module in your [por](http://blog.jayfields.com/2007/10/ruby-poro.html) class.

### `#define_filter_keys`
#### A Simple Example

A simple example might be:-

```ruby
class FilterArticles
  include Rokaki::Filterable

  def initialize(filters:)
    @filters = filters
    @articles = Article
  end

  attr_accessor :filters

  define_filter_keys :date, author: [:first_name, :last_name]

  def filter_results
    @articles = @articles.where(date: date) if date
    @articles = @articles.joins(:author).where(authors: { first_name: author_first_name }) if author_first_name
    @articles = @articles.joins(:author).where(authors: { last_name: author_last_name }) if author_last_name
  end
end

article_filter = FilterArticles.new(filters: {
  date: '10-10-10',
  author: {
    first_name: 'Steve',
    last_name: 'Martin'
  }})
article_filter.author_first_name == 'Steve'
article_filter.author_last_name == 'Martin'
article_filter.date == '10-10-10'
```

In this example Rokaki maps the "flat" attribute "keys" `date`, `author_first_name` and `author_last_name` to a `@filters` object with the expected deep structure `{ date: '10-10-10', author: { first_name: 'Steve' } }`, to make it simple to use them in filter queries.

#### A More Complex Example

```ruby
class AdvancedFilterable
  include Rokaki::Filterable

  def initialize(filters:)
    @fyltrz = filters
  end
  attr_accessor :fyltrz

  filterable_object_name :fyltrz
  filter_key_infix :__
  define_filter_keys :basic, advanced: {
    filter_key_1: [:filter_key_2, { filter_key_3: :deep_node }],
    filter_key_4: :deep_leaf_array
  }
end


advanced_filterable = AdvancedFilterable.new(filters: {
  basic: 'ABC',
  advanced: {
    filter_key_1: {
      filter_key_2: '123',
      filter_key_3: { deep_node: 'NODE' }
    },
    filter_key_4: { deep_leaf_array: [1,2,3,4] }
  }
})

advanced_filterable.advanced__filter_key_4__deep_leaf_array == [1,2,3,4]
advanced_filterable.advanced__filter_key_1__filter_key_3__deep_node == 'NODE'
```
### `#define_filter_map`
The define_filter_map method is more suited to classic "search", where you might want to search multiple fields on a model or across a graph. See the section on [filter_map](https://github.com/tevio/rokaki#2-the-filter_map-command-syntax) with OR for more on this kind of application.

This method takes a single field in the passed in filters hash and maps it to fields named in the second param, this is useful if you want to search for a single value across many different fields or associated tables simultaneously.

#### A Simple Example
```ruby
class FilterMap
  include Rokaki::Filterable

  def initialize(fylterz:)
    @fylterz = fylterz
  end
  attr_accessor :fylterz

  filterable_object_name :fylterz
  define_filter_map :query, :mapped_a, association: :field
end

filter_map = FilterMap.new(fylterz: { query: 'H2O' })

filter_map.mapped_a == 'H2O'
filter_map.association_field = 'H2O'
```

#### Additional `Filterable` options
You can specify several configuration options, for example a `filter_key_prefix` and a `filter_key_infix` to change the structure of the generated filter accessors.

`filter_key_prefix :__` would result in key accessors like `__author_first_name`

`filter_key_infix :__` would result in key accessors like `author__first_name`

`filterable_object_name :fylterz` would use an internal filter state object named `@fyltrz` instead of the default `@filters`


## `Rokaki::FilterModel` - Usage

### ActiveRecord
Include `Rokaki::FilterModel` in any ActiveRecord model (only AR >= 8.0.3 tested so far) you can generate the filter keys and the actual filter lookup code using the `filters` keyword on a model like so:-

```ruby
# Given the models
class Author < ActiveRecord::Base
  has_many :articles, inverse_of: :author
end

class Article < ActiveRecord::Base
  belongs_to :author, inverse_of: :articles, required: true
end


class ArticleFilter
  include Rokaki::FilterModel

  filters :date, :title, author: [:first_name, :last_name]

  attr_accessor :filters

  def initialize(filters:, model: Article)
    @filters = filters
    @model = model
  end
end

filter = ArticleFilter.new(filters: params[:filters])

filtered_results = filter.results

```
### Arrays of params
You can also filter collections of fields, simply pass an array of filter values instead of a single value, eg:- `{ date: '10-10-10', author: { first_name: ['Author1', 'Author2'] } }`.


### Partial matching
You can use `like` (or, if you use postgres, the case insensitive `ilike`) to perform a partial match on a specific field, there are 3 options:- `:prefix`, `:circumfix` and `:suffix`. There are two syntaxes you can use for this:-

#### 1. The `filter` command syntax


```ruby
class ArticleFilter
  include Rokaki::FilterModel

  filter :article,
    like: { # you can use ilike here instead if you use postgres and want case insensitive results
      author: {
        first_name: :circumfix,
        last_name: :circumfix
      }
    },

  attr_accessor :filters

  def initialize(filters:)
    @filters = filters
  end
end
```
Or

#### 2. The `filter_map` command syntax
`filter_map` takes the model name, then a single 'query' field and maps it to fields named in the options, this is useful if you want to search for a single value across many different fields or associated tables simultaneously. (builds on `define_filter_map`)


```ruby
class AuthorFilter
  include Rokaki::FilterModel

  filter_map :author, :query,
    like: {
      articles: {
        title: :circumfix,
        reviews: {
          title: :circumfix
        }
      },
    }

  attr_accessor :filters, :model

  def initialize(filters:)
    @filters = filters
  end
end

filters = { query: "Jiddu" }
filtered_authors = AuthorFilter.new(filters: filters).results
```

In the above example we search for authors who have written articles containing the word "Jiddu" in the title that also have reviews containing the sames word in their titles.

The above example performs an "ALL" like query, where all fields must satisfy the query term. Conversly you can use `or` to perform an "ANY", where any of the fields within the `or` will satisfy the query term, like so:-


```ruby
class AuthorFilter
  include Rokaki::FilterModel

  filter_map :author, :query,
    like: {
      articles: {
        title: :circumfix,
        or: { # the or is aware of the join and will generate a compound join aware or query
          reviews: {
            title: :circumfix
          }
        }
      },
    }

  attr_accessor :filters, :model

  def initialize(filters:)
    @filters = filters
  end
end

filters = { query: "Lao" }
filtered_authors = AuthorFilter.new(filters: filters).results
```

## CAVEATS
Active record OR over a join may require you to add something like the following in an initializer in order for it to function properly:-

### #structurally_incompatible_values_for_or

``` ruby
module ActiveRecord
  module QueryMethods
    def structurally_incompatible_values_for_or(other)
      Relation::SINGLE_VALUE_METHODS.reject { |m| send("#{m}_value") == other.send("#{m}_value") } +
        (Relation::MULTI_VALUE_METHODS - [:joins, :eager_load, :references, :extending]).reject { |m| send("#{m}_values") == other.send("#{m}_values") } +
        (Relation::CLAUSE_METHODS - [:having, :where]).reject { |m| send("#{m}_clause") == other.send("#{m}_clause") }
    end
  end
end
```

### A has one relation to a model called Or
If you happen to have a model/table named 'Or' then you can override the `or:` key syntax by specifying a special `or_key`:-

```ruby
class AuthorFilter
  include Rokaki::FilterModel

  or_key :my_or
  filter_map :author, :query,
    like: {
      articles: {
        title: :circumfix,
        my_or: { # the or is aware of the join and will generate a compound join aware or query
          or: { # The Or model has a title field
            title: :circumfix
          }
        }
      },
    }

  attr_accessor :filters, :model

  def initialize(filters:)
    @filters = filters
  end
end

filters = { query: "Syntaxes" }
filtered_authors = AuthorFilter.new(filters: filters).results
```


See [this issue](https://github.com/rails/rails/issues/24055) for details.


#### 3. The porcelain command syntax

In this syntax you will need to provide three keywords:- `filters`, `like` and `filter_model` if you are not passing in the model type and assigning it to `@model`


```ruby
class ArticleFilter
  include Rokaki::FilterModel

  filters :date, :title, author: [:first_name, :last_name]
  like title: :circumfix
  # ilike title: :circumfix # case insensitive postgres mode

  attr_accessor :filters

  def initialize(filters:, model: Article)
    @filters = filters
    @model = model
  end
end
```

Or without the model in the initializer

```ruby
class ArticleFilter
  include Rokaki::FilterModel

  filters :date, :title, author: [:first_name, :last_name]
  like title: :circumfix
  filter_model :article

  attr_accessor :filters

  def initialize(filters:)
    @filters = filters
  end
end
```

Would produce a query with a LIKE which circumfixes '%' around the filter term, like:-

```ruby
@model = @model.where('title LIKE :query', query: "%#{title}%")
```

### Deep nesting
You can filter joins both with basic matching and partial matching
```ruby
class ArticleFilter
  include Rokaki::FilterModel

  filter :author,
    like: {
      articles: {
        reviews: {
          title: :circumfix
        }
      },
    }

  attr_accessor :filters

  def initialize(filters:)
    @filters = filters
  end
end
```

### Array params
You can pass array params (and partially match them), to filters (search multiple matches) in databases that support it (postgres) by passing the `db` param to the filter keyword, and passing an array of search terms at runtine

```ruby
class ArticleFilter
  include Rokaki::FilterModel

  filter :article,
    like: {
      author: {
        first_name: :circumfix,
        last_name: :circumfix
      }
    },
    match: %i[title created_at],
    db: :postgres

  attr_accessor :filters

  def initialize(filters:)
    @filters = filters
  end
end

filterable = ArticleFilter.new(filters:
               {
                 author: {
                   first_name: ['Match One', 'Match Two']
                 }
               }
             )

filterable.results
```


## Development

### Ruby setup
After checking out the repo, run `bin/setup` to install dependencies.

### Setting up the test databases

#### Postgres
```
docker pull postgres
docker run --name rokaki-postgres -e POSTGRES_USER=rokaki -e POSTGRES_PASSWORD=rokaki -d -p 5432:5432 postgres
```

#### Mysql
```
docker pull mysql
docker run --name rokaki-mysql -e MYSQL_ROOT_PASSWORD=rokaki -e MYSQL_PASSWORD=rokaki -e MYSQL_DATABASE=rokaki -e MYSQL_USER=rokaki -d -p 3306:3306 mysql:latest mysqld
```

Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tevio/rokaki. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rokaki project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/tevio/rokaki/blob/master/CODE_OF_CONDUCT.md).
