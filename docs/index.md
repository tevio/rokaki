---
layout: home
title: Rokaki
permalink: /
---

Rokaki is a small Ruby library that helps you build safe, composable filters for ActiveRecord queries in web requests.

- Works with PostgreSQL, MySQL, and SQL Server
- Supports simple and nested filters
- LIKE-based matching with prefix/suffix/circumfix modes
- Array-of-terms matching (adapter-aware)

Get started below or jump to:
- [Usage](./usage)
- [Database adapters](./adapters)
- [Configuration](./configuration)

## Installation

Add to your application's Gemfile:

```ruby
gem "rokaki", "~> 0.11"
```

Then:

```bash
bundle install
```

## Quick start

Declare a filter map on your ActiveRecord model and compose filters.

```ruby
class Article < ActiveRecord::Base
  include Rokaki::Filterable

  filter_map do
    like :title, modes: %i[prefix suffix circumfix]
    like :content, key: :q
    nested :author do
      like :first_name
      like :last_name
    end
  end
end

# In a controller/service:
filtered = Article.filter(params)
```

Where `params` can include keys like `title_prefix`, `title_suffix`, `title_circumfix`, `q`, `author_first_name`, etc. Rokaki builds the appropriate `WHERE` clauses safely and adapter‑aware.

## Matching modes

- prefix: matches values that start with given term(s)
- suffix: matches values that end with given term(s)
- circumfix: matches values that contain given term(s)

All modes accept either a single string or an array of terms.

## Next steps

- Learn the full DSL and examples in [Usage](./usage)
- See adapter specifics (PostgreSQL/MySQL/SQL Server) in [Database adapters](./adapters)
- Configure connections and environment variables in [Configuration](./configuration)
