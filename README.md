# Rokaki

This gem was born out of a desire to dry up filtering services in Rails or any ruby app that uses the concept of `filters`.

It's a simple gem that just provides you with a basic dsl based on the filter params that you might pass through from a web request.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rokaki'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rokaki

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

This would map attributes `date`, `author_first_name` and `author_last_name`, from a filters object with the structure `{ date: '10-10-10', author: { first_name: 'Shteeve' } }`.

## Additional options
You can specify a `filter_key_prefix` and a `filter_key_infix` to change the structure of the accessors.

`filter_key_prefix :__` would result in key accessors like `__author_first_name`
`filter_key_infix :__` would result in key accessors like `author__first_name`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rokaki. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rokaki project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/rokaki/blob/master/CODE_OF_CONDUCT.md).
