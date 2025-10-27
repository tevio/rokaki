---
layout: page
title: Usage
permalink: /usage
---

This page shows how to use Rokaki to define filters and apply them to ActiveRecord relations.

## Installation

Add the gem to your Gemfile and bundle:

```ruby
gem "rokaki", "~> 0.15"
```

```bash
bundle install
```

## Basic setup

Include `Rokaki::Filterable` in models you want to filter, and define a `filter_map` with fields and nested associations.

```ruby
class Author < ActiveRecord::Base
  has_many :articles
end

class ArticleQuery
  include Rokaki::FilterModel
  belongs_to :author

  # Choose model and adapter
  filter_model :article, db: :postgres # or :mysql, :sqlserver, :oracle, :sqlite

  # Map a single query key (:q) to multiple LIKE targets
  define_query_key :q
  like title: :circumfix, content: :circumfix

  # Nested LIKEs via hash mapping
  like author: { first_name: :prefix, last_name: :suffix }
end
```

## Applying filters

Call `Model.filter(params)` to build a relation based on supported keys.

```ruby
params = {
  title_prefix: "Intro",
  q: ["ruby", "rails"],
  author_last_name: "martin"
}

filtered = Article.filter(params)
# => ActiveRecord::Relation (chainable)
```

You can keep chaining other scopes/clauses:

```ruby
Article.filter(params).order(published: :desc).limit(20)
```

## LIKE modes and affix options

Declare the LIKE mode via the value in your `like` mapping (there is no `modes:` option). For example: `like title: :prefix`.

- `prefix` → matches strings that start with a term (pattern: `%term`)
- `suffix` → matches strings that end with a term (pattern: `term%`)
- `circumfix` → matches strings that contain a term (pattern: `%term%`)
  - Synonyms supported: `:parafix`, `:confix`, `:ambifix` (all behave the same as `:circumfix`)

Each accepts a single string or an array of strings. Rokaki generates adapter‑aware SQL:

- PostgreSQL: `LIKE`/`ILIKE` with `ANY (ARRAY[...])`
- MySQL: `LIKE`/`LIKE BINARY` and, in nested-like contexts, `REGEXP` where designed
- SQL Server: `LIKE` with safe escaping; arrays expand into OR chains of parameterized `LIKE` predicates

## Nested filters

Use `nested :association` to scope filters to joined tables. Rokaki handles the necessary joins and qualified columns.

```ruby
filter_map do
  nested :author do
    like :first_name, key: :author_first
  end
end
```

Params would include `author_first`, `author_first_prefix`, etc.

## Customization tips

- Use `key:` to map a filter to a different params key.
- Combine multiple filters; Rokaki composes them with `AND` by default.
- For advanced cases, write custom filters in your app by extending the DSL (see source for `BasicFilter`/`NestedFilter`).


## Block-form DSL

Note: The block-form DSL is available starting in Rokaki 0.13.0.

Rokaki also supports a block-form DSL that is equivalent to the argument-based form. Use it when you prefer grouping your mappings in a single block.

### FilterModel block form

```ruby
class ArticleQuery
  include Rokaki::FilterModel

  # Choose model and adapter
  filter_model :article, db: :postgres # or :mysql, :sqlserver

  # Declare a single query key used by all LIKE/equality filters below
  define_query_key :q

  # Declare mappings inside a block
  filter_map do
    # LIKE mappings on the base model
    like title: :circumfix, content: :circumfix

    # Nested mappings on associations
    nested :author do
      like first_name: :prefix, last_name: :suffix

      # You can also declare equality filters in block form
      filters :id
    end
  end

  attr_accessor :filters
  def initialize(filters: {})
    @filters = filters
  end
end

# Usage
ArticleQuery.new(filters: { q: ["Intro", "Guide"] }).results
```

Notes:
- Modes are declared by the values in your `like` mapping (`:prefix`, `:suffix`, `:circumfix`). Synonyms `:parafix`, `:confix`, `:ambifix` behave like `:circumfix`.
- Arrays for `q` are supported across adapters. PostgreSQL uses `ANY (ARRAY[...])`, MySQL/SQL Server expand to OR chains as appropriate.

### Filterable block form

Use the block form to define simple key accessors (no SQL). Useful for plain Ruby objects or when building a mapping layer.

```ruby
class ArticleFilters
  include Rokaki::Filterable
  filter_key_prefix :__

  filter_map do
    filters :date, author: [:first_name, :last_name]

    nested :author do
      nested :location do
        filters :city
      end
    end
  end

  # Expect a #filters method that returns a hash
  attr_reader :filters
  def initialize(filters: {})
    @filters = filters
  end
end

f = ArticleFilters.new(filters: {
  date: '2025-01-01',
  author: { first_name: 'Ada', last_name: 'Lovelace', location: { city: 'London' } }
})

f.__date                        # => '2025-01-01'
f.__author__first_name          # => 'Ada'
f.__author__last_name           # => 'Lovelace'
f.__author__location__city      # => 'London'
```

Tips:
- `filter_key_prefix` and `filter_key_infix` control the generated accessor names.
- Inside the block, `nested :association` affects all `filters` declared within it.


## Dynamic runtime listener (no code changes needed)

You can construct a Rokaki filter class at runtime from a payload (e.g., JSON → Hash) and use it immediately — no prior class is required. Rokaki will compile the tiny class on the fly and generate the methods once.

### FilterModel example
```ruby
# Example payload (e.g., parsed JSON)
payload = {
  model: :article,
  db: :postgres,        # or :mysql, :sqlserver, :oracle
  query_key: :q,        # the key in params with search term(s)
  like: {               # like mappings (deeply nested allowed)
    title: :circumfix,
    author: { first_name: :prefix }
  }
}

# Build an anonymous class at runtime and use it immediately
listener = Class.new do
  include Rokaki::FilterModel

  filter_model payload[:model], db: payload[:db]
  define_query_key payload[:query_key]

  filter_map do
    like payload[:like]
  end

  attr_accessor :filters
  def initialize(filters: {})
    @filters = filters
  end
end

results = listener.new(filters: { q: ["Ada", "Turing"] }).results
# => ActiveRecord::Relation
```

### Filterable example (no SQL)
```ruby
mapper = Class.new do
  include Rokaki::Filterable
  filter_key_prefix :__

  filter_map do
    filters :date, author: [:first_name, :last_name]
  end

  attr_reader :filters
  def initialize(filters: {})
    @filters = filters
  end
end

m = mapper.new(filters: { date: '2025-01-01', author: { first_name: 'Ada', last_name: 'Lovelace' } })
m.__date                   # => '2025-01-01'
m.__author__first_name     # => 'Ada'
m.__author__last_name      # => 'Lovelace'
```

Notes:
- This approach is production‑ready and requires no core changes to Rokaki.
- You can cache the generated class by a digest of the payload to avoid recompiling.
- For maximum safety, validate/allow‑list models/columns coming from untrusted payloads.
