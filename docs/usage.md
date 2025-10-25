---
layout: page
title: Usage
permalink: /usage
---

This page shows how to use Rokaki to define filters and apply them to ActiveRecord relations.

## Installation

Add the gem to your Gemfile and bundle:

```ruby
gem "rokaki", "~> 0.11"
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

class Article < ActiveRecord::Base
  include Rokaki::Filterable
  belongs_to :author

  filter_map do
    # Simple LIKE filters
    like :title, modes: %i[prefix suffix circumfix]
    like :content, key: :q

    # Boolean or exact filters can go through custom blocks or other helpers
    # eq :status

    # Nested filters on associations
    nested :author do
      like :first_name
      like :last_name
    end
  end
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

## LIKE modes and multi-term input

- `prefix` → matches strings that start with a term
- `suffix` → matches strings that end with a term
- `circumfix` → matches strings that contain a term

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
