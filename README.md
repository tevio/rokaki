# Rokaki
[![Gem Version](https://badge.fury.io/rb/rokaki.svg)](https://badge.fury.io/rb/rokaki)

This gem was born out of a desire to dry up filtering services in Rails or any ruby app that uses the concept of `filters`.

It's a simple gem that just provides you with a basic dsl based on the filter params that you might pass through from a web request.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rokaki', git: 'https://github.com/tevio/rokaki.git'
```

And then execute:

    $ bundle

## Usage

To use the basic DSL include the `Rokaki::Filterable` module

A simple example might be:-

```
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
```

This maps attributes `date`, `author_first_name` and `author_last_name` to a filters object with the structure `{ date: '10-10-10', author: { first_name: 'Shteeve' } }`.

## Additional options
You can specify a `filter_key_prefix` and a `filter_key_infix` to change the structure of the accessors.

`filter_key_prefix :__` would result in key accessors like `__author_first_name`

`filter_key_infix :__` would result in key accessors like `author__first_name`

## ActiveRecord
Include `Rokaki::FilterModel` in any ActiveRecord model (only AR >= 6.0.0 tested so far) you can generate the filter keys and the actual filter lookup code using the `filters` keyword on a model like so:-

```
# Given the models
class Author < ActiveRecord::Base
  has_many :articles, inverse_of: :author
end

class Article < ActiveRecord::Base
  belongs_to :author, inverse_of: :articles, required: true
end


class ArticleFilter
  include FilterModel

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

### Partial matching
You can use `like` to perform a partial match on a specific key, there are 3 options:- `:prefix`, `:circumfix` and `:suffix`. There are two syntaxes you can use for this:-

#### 1. The `filter` command syntax


```
class ArticleFilter
  include FilterModel

  filter :article,
    like: {
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


```
class ArticleFilter
  include FilterModel

  filters :date, :title, author: [:first_name, :last_name]
  like title: :circumfix

  attr_accessor :filters

  def initialize(filters:, model: Article)
    @filters = filters
    @model = model
  end
end
```

Or without the model in the initializer

```
class ArticleFilter
  include FilterModel

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

```
@model = @model.where('title LIKE :query', query: "%#{title}%")
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
