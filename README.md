# Rokaki
[![Gem Version](https://badge.fury.io/rb/rokaki.svg)](https://badge.fury.io/rb/rokaki)

This gem was born out of a desire to dry up filtering services in Rails apps or any Ruby app that uses the concept of "filters" or "facets".

There are two modes of use `Filterable` and `FilterModel` that can be activated through the use of two mixins respectively, `include Rokaki::Filterable` or `include Rokaki::FilterModel`.
## Installation

Add this line to your application's Gemfile:

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
    @articles = @articles.joins(:author).where(author: { first_name: author_first_name }) if author_first_name
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

filter_map = FilterMap.new(fytlerz: { query: 'H2O' })

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
Include `Rokaki::FilterModel` in any ActiveRecord model (only AR >= 6.0.0 tested so far) you can generate the filter keys and the actual filter lookup code using the `filters` keyword on a model like so:-

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

#### 2. The porcelain command syntax

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tevio/rokaki. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rokaki project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/tevio/rokaki/blob/master/CODE_OF_CONDUCT.md).
