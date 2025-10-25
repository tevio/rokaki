---
layout: home
title: Rokaki
permalink: /
---

Rokaki is a small Ruby library that helps you build safe, composable filters for ActiveRecord queries in web requests.

- Works with PostgreSQL, MySQL, and SQL Server
- Supports simple and nested filters
- LIKE-based matching with prefix/suffix/circumfix modes (circumfix also accepts synonyms: parafix, confix, ambifix)
- Array-of-terms matching (adapter-aware)

Get started below or jump to:
- [Usage](./usage)
- [Database adapters](./adapters)
- [Configuration](./configuration)

## Installation

Add to your application's Gemfile:

```ruby
gem "rokaki", "~> 0.13"
```

Then:

```bash
bundle install
```

## Quick start

You can declare mappings in two ways: argument-based (original) or block-form DSL. Both are equivalent.

Argument-based form:

```ruby
class ArticleQuery
  include Rokaki::FilterModel

  # Tell Rokaki which model to query and which DB adapter semantics to use
  filter_model :article, db: :postgres # or :mysql, :sqlserver

  # Map a single query key (:q) to multiple LIKE targets on Article
  define_query_key :q
  like title: :circumfix, content: :circumfix

  # Nested LIKEs on associated models are expressed with hashes
  like author: { first_name: :prefix, last_name: :suffix }

  attr_accessor :filters
  def initialize(filters: {})
    @filters = filters
  end
end

# In a controller/service:
filtered = ArticleQuery.new(filters: params).results
```

Block-form DSL (same behavior):

```ruby
class ArticleQuery
  include Rokaki::FilterModel

  filter_model :article, db: :postgres # or :mysql, :sqlserver
  define_query_key :q

  filter_map do
    like title: :circumfix, content: :circumfix
    nested :author do
      like first_name: :prefix, last_name: :suffix
      # You can also declare equality filters inside nested contexts
      filters :id
    end
  end

  attr_accessor :filters
  def initialize(filters: {})
    @filters = filters
  end
end

# In a controller/service:
filtered = ArticleQuery.new(filters: params).results
```

Where `params` can include keys like `q`, `author_first_name`, `author_last_name`, etc. The LIKE mode for each key is defined in your `like` mapping (e.g., `title: :circumfix`), and Rokaki builds the appropriate `WHERE` clauses safely and adapter‑aware.

## Matching modes

- prefix: matches values that start with given term(s)
- suffix: matches values that end with given term(s)
- circumfix: matches values that contain given term(s)

All modes accept either a single string or an array of terms.

## What’s new in 0.13.0

- Block-form DSL parity across both FilterModel and Filterable
- Circumfix affix synonyms supported: :parafix, :confix, :ambifix
- SQL Server adapter support and CI coverage
- ENV overrides for all adapters in test helpers; improved DB bootstrap in specs
- Documentation site via GitHub Pages

## Next steps

- Learn the full DSL and examples in [Usage](./usage)
- See adapter specifics (PostgreSQL/MySQL/SQL Server) in [Database adapters](./adapters)
- Configure connections and environment variables in [Configuration](./configuration)
